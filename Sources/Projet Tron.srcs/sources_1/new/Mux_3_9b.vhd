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

ENTITY Mux_3_9b IS
    PORT (
        w_select : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
        init_x : IN STD_LOGIC_VECTOR (8 DOWNTO 0);
        J1_x : IN STD_LOGIC_VECTOR (8 DOWNTO 0);
        J2_x : IN STD_LOGIC_VECTOR (8 DOWNTO 0);
        vga_x : OUT STD_LOGIC_VECTOR (8 DOWNTO 0));
END Mux_3_9b;

ARCHITECTURE Behavioral OF Mux_3_9b IS

BEGIN
    PROCESS (w_select, init_x, J1_x, J2_x)
    BEGIN

        IF (w_select = "00") THEN
            vga_x <= init_x;

        ELSIF (w_select = "01") THEN
            vga_x <= J1_x;

        ELSIF (w_select = "10") THEN
            vga_x <= J2_x;

        ELSE
            vga_x <= init_x;

        END IF;
    END PROCESS;
END Behavioral;