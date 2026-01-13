----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/17/2025 09:52:25 AM
-- Design Name: 
-- Module Name: Mux_init - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY Mux_3_2b IS
    PORT (
        w_select : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
        init_data_in : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
        J1_data_in : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
        J2_data_in : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
        vga_data_in : OUT STD_LOGIC_VECTOR (1 DOWNTO 0));
END Mux_3_2b;

ARCHITECTURE Behavioral OF Mux_3_2b IS

BEGIN
    PROCESS (w_select, init_data_in, J1_data_in, J2_data_in)
    BEGIN

        IF (w_select = "00") THEN
            vga_data_in <= init_data_in;

        ELSIF (w_select = "01") THEN
            vga_data_in <= J1_data_in;

        ELSIF (w_select = "10") THEN
            vga_data_in <= J2_data_in;

        ELSE
            vga_data_in <= init_data_in;

        END IF;
    END PROCESS;
END Behavioral;