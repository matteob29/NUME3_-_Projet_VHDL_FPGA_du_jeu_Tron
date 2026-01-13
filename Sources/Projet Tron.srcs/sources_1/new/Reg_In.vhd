----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/15/2025 11:08:36 AM
-- Design Name: 
-- Module Name: mux_8 - Behavioral
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
USE IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY Reg_In IS
    PORT (
        clk : IN STD_LOGIC;
        E : IN STD_LOGIC;
        S : OUT STD_LOGIC
    );
END Reg_In;

ARCHITECTURE Behavioral OF Reg_In IS
    SIGNAL s_reg1 : STD_LOGIC := '0';
    SIGNAL s_reg2 : STD_LOGIC := '0';
BEGIN
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            s_reg1 <= E;
            s_reg2 <= s_reg1; -- temporise 2 cycles de clock pour éviter les rebonds
        END IF;
    END PROCESS;

    S <= s_reg2;
END Behavioral;