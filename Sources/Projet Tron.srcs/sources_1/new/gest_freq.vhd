----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/08/2025 12:20:58 PM
-- Design Name: 
-- Module Name: gest_freq - Behavioral
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

ENTITY gest_freq IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        ce_fsm : OUT STD_LOGIC);
END gest_freq;

ARCHITECTURE Behavioral OF gest_freq IS

    SIGNAL clk_200 : INTEGER RANGE 0 TO 499999;
BEGIN

    PROCESS (clk)
    BEGIN
        IF (clk'event AND clk = '1') THEN
            IF rst = '1' THEN
                ce_fsm <= '0';
            ELSIF clk_200 = 499999 THEN
                clk_200 <= 0;
                ce_fsm <= '1';
            ELSE
                clk_200 <= clk_200 + 1;
                ce_fsm <= '0';
            END IF;
        END IF;
    END PROCESS;

END Behavioral;