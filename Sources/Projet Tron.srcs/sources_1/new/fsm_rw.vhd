----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/03/2025 11:10:00 AM
-- Design Name: 
-- Module Name: fsm_rw - Behavioral
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

ENTITY fsm_rw IS
    PORT (
        clk : IN STD_LOGIC;
        ce_fsm : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        J1_loses : IN STD_LOGIC;
        J2_loses : IN STD_LOGIC;
        end_init : IN STD_LOGIC;

        J1_b_center : IN STD_LOGIC;

        state_fsm_rw : OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
        w_select : OUT STD_LOGIC_VECTOR (1 DOWNTO 0);

        data_read : OUT STD_LOGIC;
        data_write : OUT STD_LOGIC
    );
END fsm_rw;

ARCHITECTURE Behavioral OF fsm_rw IS

    TYPE etat IS (INIT, READ_1, WRITE_1, READ_2, WRITE_2, WIN_J1, WIN_J2);
    SIGNAL state : etat := INIT;
    SIGNAL next_state : etat := INIT;
BEGIN

    PROCESS (clk, rst)
    BEGIN
        IF (rst = '1') THEN
            state <= INIT;
        ELSIF (clk'event AND clk = '1') THEN
            IF (ce_fsm = '1') THEN
                state <= next_state;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (state)
    BEGIN
        CASE (state) IS
            WHEN INIT =>
                state_fsm_rw <= "100";
                w_select <= "00";
                data_write <= '1';
                data_read <= '0';

            WHEN READ_1 =>
                state_fsm_rw <= "000";
                w_select <= "01";
                data_write <= '0';
                data_read <= '1';

            WHEN WRITE_1 =>
                state_fsm_rw <= "001";
                w_select <= "01";
                data_write <= '1';
                data_read <= '0';

            WHEN READ_2 =>
                state_fsm_rw <= "010";
                w_select <= "10";
                data_write <= '0';
                data_read <= '1';

            WHEN WRITE_2 =>
                state_fsm_rw <= "011";
                w_select <= "10";
                data_write <= '1';
                data_read <= '0';

            WHEN WIN_J1 =>
                state_fsm_rw <= "101";

            WHEN WIN_J2 =>
                state_fsm_rw <= "110";

            WHEN OTHERS =>
                state_fsm_rw <= "111";
                w_select <= "11";
                data_write <= '0';
                data_read <= '0';

        END CASE;
    END PROCESS;

    PROCESS (state, J1_loses, J2_loses, end_init, ce_fsm)
    BEGIN
        CASE (state) IS
            WHEN INIT =>
                IF (end_init = '1') THEN
                    next_state <= READ_1;
                ELSE
                    next_state <= INIT;
                END IF;

            WHEN READ_1 =>

                IF (J1_loses = '1') THEN
                    next_state <= WIN_J2;
                ELSIF (ce_fsm = '1') THEN
                    next_state <= WRITE_1;
                ELSE
                    next_state <= READ_1;
                END IF;

            WHEN WRITE_1 =>
                IF (ce_fsm = '1') THEN
                    next_state <= READ_2;
                ELSIF (J1_loses = '1') THEN
                    next_state <= WIN_J2;
                ELSE
                    next_state <= WRITE_1;
                END IF;

            WHEN READ_2 =>

                IF (J2_loses = '1') THEN
                    next_state <= WIN_J1;
                ELSIF (ce_fsm = '1') THEN
                    next_state <= WRITE_2;
                ELSE
                    next_state <= READ_2;
                END IF;

            WHEN WRITE_2 =>
                IF (ce_fsm = '1') THEN
                    next_state <= READ_1;
                ELSIF (J2_loses = '1') THEN
                    next_state <= WIN_J1;
                ELSE
                    next_state <= WRITE_2;
                END IF;

            WHEN WIN_J1 =>
                IF (J1_b_center = '1') THEN
                    next_state <= INIT;
                ELSE
                    next_state <= WIN_J1;
                END IF;

            WHEN WIN_J2 =>
                IF (J1_b_center = '1') THEN
                    next_state <= INIT;
                ELSE
                    next_state <= WIN_J2;
                END IF;

            WHEN OTHERS =>
                next_state <= INIT;

        END CASE;
    END PROCESS;

END Behavioral;