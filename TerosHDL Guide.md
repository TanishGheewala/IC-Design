# Running `system.sv` in TerosHDL
 
1. Clone the repo (or `git pull` if already cloned), and make sure the TerosHDL extension is installed & configured in VS Code.
2. Open `system.sv` and find the `instruction_memory` instantiation:
```systemverilog
   instruction_memory #(
                        .MEM_INITIAL_FILE("test_program.hex"))
                       rom (.addr(rom_if.addr),
                        .inst(rom_if.inst)
                       );
```
   Update the path inside `.MEM_INITIAL_FILE("...")` to point at `test_program.hex`. 
   <br>
   Use the full absolute path on your machine (e.g. `C:/.../IC-Design/Verification/test_program.hex`).
 
3. In the TerosHDL sidebar, click **Add Project** and create a new generic project.
4. Add `system_compile_order.csv` to **Watchers**.
5. Make sure `system_tb` is selected as the top-level module to run.
6. Click **Run**.
You should see `x1 = 5 (expect 5)` in the output log.