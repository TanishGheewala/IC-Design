"""
Simple script to send and receive data with out fpga for testing.
This script is for the alu implemenation on the fpga. It opens
a serial line to recieve and transmit data via uart. May add self
checking at a later date.

"""

import serial

#Open communication line with fpga through uart
ser = serial.serial('COM3', 9600, timeout=1)

#Get all inputs to alu
#Only 8 bit width for this test
opcode = input("Enter Opcode in integer form: ")
input_1 = input("Enter data_in_0 in integer form: ")
input_2 = input("Enter data_in_1 in integer form: ")

#Integer cast the inputs to ensute correct valeus sent
opcode = int(opcode)
input_1 = int(input_1)
input_2 = int(input_2)

#Write to fpga
ser.write(opcode)
ser.write(input_1)
ser.write(input_2)

#Recieve output from fpga
alu_output = ser.read()
ser.close

#Print Result
print("ALU output: ")
print(alu_output)


