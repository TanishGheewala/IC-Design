# Launch with: bash eqy/run_eqy.sh <design>|all
#
# Logic equivalence check (golden RTL vs Genus netlist) with Yosys EQY.
# Sources the same ../config.tcl as run_genus.tcl, so each design's top
# module, filelist, libraries and out/reports folders are defined once.

set EQY_DIR   $env(EQY_DIR)
set GENUS_DIR $env(GENUS_DIR)
set REQUEST   $env(EQY_DESIGN)

# config.tcl looks up TOP_OF($DESIGN) on its last lines, so sourcing it with
# "all" stops there - after TOP_OF is defined, which is all we need here.
set env(DESIGN) $REQUEST
if {[catch {source $GENUS_DIR/config.tcl} err] && [info exists TOP_OF($REQUEST)]} {
    puts stderr "ERROR in $GENUS_DIR/config.tcl: $err"
    exit 1
}
if {![info exists TOP_OF]} {
    puts stderr "ERROR: no TOP_OF table in $GENUS_DIR/config.tcl"
    exit 1
}

set KNOWN [lsort [array names TOP_OF]]
if {$REQUEST eq "all"} {
    set designs $KNOWN
} elseif {[lsearch -exact $KNOWN $REQUEST] >= 0} {
    set designs [list $REQUEST]
} else {
    puts stderr "ERROR: unknown design '$REQUEST'. Known: $KNOWN (or 'all')"
    exit 1
}

source $EQY_DIR/config.tcl

# yosys-slang errors on simulation-only print tasks ($strobe, $monitor, ...)
# instead of ignoring them like Genus/Conformal do, and has no option to skip
# them. This writes a copy of an RTL file with each such call replaced by an
# empty statement ';' (keeps 'if (x) $display(..);' valid). Newlines inside a
# removed call are kept so error line numbers still match the original file.
# Returns the number of calls removed.
proc strip_sim_tasks {src dst} {
    set fp [open $src r]
    set text [read $fp]
    close $fp

    set re {\$(?:f?(?:display|strobe|write|monitor)[bho]?|monitoron|monitoroff)\s*(?:\([^;]*\))?\s*;}
    set out   ""
    set start 0
    set count 0
    while {[regexp -indices -start $start $re $text match]} {
        lassign $match s e
        set hit [string range $text $s $e]
        append out [string range $text $start [expr {$s - 1}]] ";" \
                   [string repeat "\n" [regexp -all {\n} $hit]]
        set start [expr {$e + 1}]
        incr count
    }
    append out [string range $text $start end]

    file mkdir [file dirname $dst]
    set fp [open $dst w]
    puts -nonewline $fp $out
    close $fp
    return $count
}

# Pulls the key facts out of an EQY output log so they fit in one table row.
# Returns a dict: result (PASS/FAIL/ERROR/...), eq, neq (partition counts),
# neq_parts (names of non-equivalent partitions) and error (first ERROR line).
proc parse_eqy_log {log} {
    set res [dict create result "" eq 0 neq 0 neq_parts {} error ""]
    if {![file exists $log]} { return $res }

    set eq_parts  {}
    set neq_parts {}
    set fp [open $log r]
    while {[gets $fp line] >= 0} {
        # Drop the "EQY hh:mm:ss [design] " prefix.
        regsub {^EQY\s+[0-9:]+\s+\[[^]]*\]\s*} $line "" msg

        if {[regexp -nocase {DONE\s*\(\s*(\w+)\s*,\s*rc\s*=\s*\d+} $msg -> r]} {
            dict set res result [string toupper $r]
        } elseif {[regexp -nocase {partition '([^']+)'} $msg -> part]} {
            if {[regexp -nocase {fail|could not|unable|not equiv|counterexample} $msg]} {
                if {[lsearch -exact $neq_parts $part] < 0} { lappend neq_parts $part }
            } elseif {[regexp -nocase {proved} $msg]} {
                if {[lsearch -exact $eq_parts $part] < 0} { lappend eq_parts $part }
            }
        }
        if {[dict get $res error] eq "" && [regexp {ERROR} $msg]} {
            dict set res error [string trim $msg]
        }
    }
    close $fp

    dict set res eq        [llength $eq_parts]
    dict set res neq       [llength $neq_parts]
    dict set res neq_parts $neq_parts
    return $res
}

# Shortens a note so the summary table stays one line per design.
proc clip {text {max 58}} {
    if {[string length $text] <= $max} { return $text }
    return "[string range $text 0 [expr {$max - 4}]]..."
}

set WORK_DIR $EQY_DIR/work
file mkdir $WORK_DIR
# One row per design: {design result eq neq note neq_parts}
set rows {}

foreach design $designs {
    # Per-design settings: TOP_MODULE, FILELIST, OUT_DIR, RPT_DIR, STD_LIB, ...
    set env(DESIGN) $design
    source $GENUS_DIR/config.tcl

    set netlist $OUT_DIR/${design}_netlist.v
    if {![file exists $netlist]} {
        puts "=== $design: skipped (no netlist)"
        lappend rows [list $design SKIPPED - - "no netlist - run run_genus.sh $design" {}]
        continue
    }

    # Golden RTL = the filelist Genus reads. Non-HDL entries (e.g. a .lib) are skipped.
    set rtl_files {}
    set fp [open $FILELIST r]
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} continue
        if {[lsearch -exact {.sv .v .svh .vh} [file extension $line]] < 0} continue
        lappend rtl_files $line
    }
    close $fp

    # Read the original files, or cleaned copies (see strip_sim_tasks) kept
    # under work/rtl/<design>/ with the same relative paths. The repo RTL is
    # never modified.
    set gold_files {}
    set stripped   0
    foreach f $rtl_files {
        set src [file join $REPO_ROOT $f]
        if {$EQY_STRIP_SIM_TASKS} {
            set dst [file join $WORK_DIR rtl $design $f]
            set n [strip_sim_tasks $src $dst]
            if {$n > 0} { puts "  $design: removed $n simulation print call(s) from $f" }
            incr stripped $n
            lappend gold_files $dst
        } else {
            lappend gold_files $src
        }
    }

    # --single-unit: macros from one file (e.g. macros.vh) are visible in the
    # following files, the same way Genus reads the filelist.
    set slang_opts [list --single-unit --top $TOP_MODULE]
    foreach d $EQY_DEFINES  { lappend slang_opts -D $d }
    foreach i $INCLUDE_DIRS { lappend slang_opts -I $i }

    # Macros (e.g. SRAM) are black boxes in BOTH designs; only their
    # connections are compared.
    set macro_libs {}
    foreach lib $EXTRA_LIBS { lappend macro_libs "read_liberty -lib $lib" }
    set macro_libs [join $macro_libs "\n"]

    set depth $EQY_DEPTH_DEFAULT
    if {[info exists EQY_DEPTH($design)]} { set depth $EQY_DEPTH($design) }

    set eqy_file $WORK_DIR/${design}.eqy
    set fp [open $eqy_file w]
    puts $fp "# Generated by run_eqy.tcl for '$design' - edit run_eqy.tcl or config.tcl, not this file.

# Golden: RTL, read with the slang SystemVerilog frontend (handles interfaces)
\[gold\]
$macro_libs
plugin -i slang
read_slang $slang_opts $gold_files
prep -flatten -top $TOP_MODULE

# Gate: Genus netlist. The standard-cell .lib is read WITHOUT -lib so each
# cell gets its logic from the 'function' attributes.
\[gate\]
read_liberty -ignore_miss_func $STD_LIB
$macro_libs
read_verilog $netlist
prep -flatten -top $TOP_MODULE

\[strategy sby\]
use sby
depth $depth
engine $EQY_ENGINE"
    close $fp

    # EQY output goes to work/<design>.out (EQY_QUIET 1) or the terminal.
    set out_file $WORK_DIR/${design}.out
    puts -nonewline "=== $design: running EQY (top $TOP_MODULE, depth $depth) ... "
    flush stdout
    cd $WORK_DIR
    if {$EQY_QUIET} {
        set rc [catch {exec eqy -f -d $design $eqy_file >& $out_file}]
    } else {
        puts ""
        set rc [catch {exec >@stdout 2>@stderr eqy -f -d $design $eqy_file}]
    }

    # Keep the EQY log next to the Genus reports (work/ is not in git).
    set log $WORK_DIR/$design/logfile.txt
    if {![file exists $log]} { set log $out_file }
    if {[file exists $log]} {
        file mkdir $RPT_DIR
        file copy -force $log $RPT_DIR/${design}_eqy.log
    }

    # Result: EQY's own DONE(...) status, else PASS/FAIL from its exit code.
    set info   [parse_eqy_log $log]
    set result [dict get $info result]
    if {$result eq ""} { set result [expr {$rc == 0 ? "PASS" : "FAIL"}] }
    if {$rc != 0 && $result eq "PASS"} { set result FAIL }

    set notes {}
    if {[dict get $info error] ne ""} {
        lappend notes [dict get $info error]
    } elseif {$result eq "PASS" && [dict get $info eq] == 0} {
        lappend notes "no partition results found in log - check it"
    }
    if {$stripped > 0} { lappend notes "$stripped sim print(s) removed" }

    puts $result
    lappend rows [list $design $result [dict get $info eq] [dict get $info neq] \
                       [join $notes "; "] [dict get $info neq_parts]]
}

# ----------------------------------------------------------------------------
# Summary table (terminal + eqy/work/<design>/eqy_summary.rpt)
# ----------------------------------------------------------------------------
# Date from the system 'date' command: 'clock format' needs Tcl's msgcat
# package, which Yosys' built-in Tcl (used when there's no tclsh) doesn't have.
if {[catch {exec date "+%Y-%m-%d %H:%M"} run_date]} { set run_date "" }

set line  [string repeat "=" 92]
set table {}
lappend table $line
lappend table " EQY equivalence summary (RTL vs Genus netlist)   $run_date"
lappend table $line
lappend table [format " %-10s %-8s %6s %7s   %s" Design Result EQ NON-EQ Notes]
lappend table [format " %-10s %-8s %6s %7s   %s" ---------- -------- ------ ------- [string repeat - 30]]

set failed 0
set neq_lines {}
foreach r $rows {
    lassign $r design result eq neq note parts
    set flag [expr {$result in {PASS SKIPPED} ? " " : "!"}]
    lappend table [format "%s%-10s %-8s %6s %7s   %s" $flag $design $result $eq $neq [clip $note]]
    if {$result ni {PASS SKIPPED}} { incr failed }
    foreach p $parts { lappend neq_lines "   $design: $p" }
}
lappend table $line

if {[llength $neq_lines] > 0} {
    lappend table " Non-equivalent partitions:"
    foreach l $neq_lines { lappend table $l }
    lappend table $line
}
lappend table " EQ / NON-EQ = number of partitions proven / not proven equivalent."
lappend table " Full logs: reports/<design>/<design>_eqy.log    Rows marked ! need attention."
lappend table $line

set report [join $table "\n"]
puts "\n$report"

# Save the table in each design's EQY work folder (eqy/work/<design>/), and
# also in eqy/work/ when several designs were run together.
set saved {}
foreach r $rows {
    set run_dir [file join $WORK_DIR [lindex $r 0]]
    if {[file isdirectory $run_dir]} { lappend saved [file join $run_dir eqy_summary.rpt] }
}
if {[llength $designs] > 1} { lappend saved [file join $WORK_DIR eqy_summary.rpt] }
foreach path $saved {
    set fp [open $path w]
    puts $fp $report
    close $fp
    puts "Saved to $path"
}

exit [expr {$failed > 0 ? 1 : 0}]
