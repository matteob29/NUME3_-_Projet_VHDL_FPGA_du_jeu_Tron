----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/03/2025 09:52:52 AM
-- Design Name: 
-- Module Name: fsm_position - Behavioral
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

ENTITY fsm_pos_J1 IS
    GENERIC (
        hauteur : INTEGER := 240;
        largeur : INTEGER := 320);

    PORT (
        rst : IN STD_LOGIC;
        clk : IN STD_LOGIC;
        ce_fsm : IN STD_LOGIC;

        b_up : IN STD_LOGIC;
        b_down : IN STD_LOGIC;
        b_left : IN STD_LOGIC;
        b_right : IN STD_LOGIC;

        data_out : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
        data_rout : IN STD_LOGIC;

        state_fsm_rw : IN STD_LOGIC_VECTOR (2 DOWNTO 0);
        J1_x : OUT STD_LOGIC_VECTOR (8 DOWNTO 0);
        J1_y : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
        J1_data_in : OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
        J1_loses : OUT STD_LOGIC
    );
END fsm_pos_J1;

ARCHITECTURE Behavioral OF fsm_pos_J1 IS
    TYPE etat IS (INIT, UP, DOWN, LEFT, RIGHT, LOSE);
    SIGNAL direction, next_direction : etat := INIT;
    SIGNAL pos_x_actuelle, pos_x_futur : INTEGER RANGE 0 TO 319 := 0;
    SIGNAL pos_y_actuelle, pos_y_futur : INTEGER RANGE 0 TO 239 := 0;
BEGIN

    J1_data_in <= "01"; -- j1 : bleu

    PROCESS (clk, rst)
    BEGIN
        IF (rst = '1') THEN
            direction <= INIT;
            pos_x_actuelle <= 80;
            pos_y_actuelle <= 120;
            J1_loses <= '0';

        ELSIF (clk'event AND clk = '1') THEN


            IF (state_fsm_rw = "100") THEN -- INIT
                pos_x_actuelle <= 80;
                pos_y_actuelle <= 120;
                J1_loses <= '0';
                direction <= INIT;

            ELSIF (ce_fsm = '1') AND (state_fsm_rw = "000") THEN -- READ_1

                direction <= next_direction;

                IF (data_rout = '1') AND (direction /= INIT) THEN
                    IF (data_out /= "00") THEN
                        J1_loses <= '1';
                    END IF;
                END IF;

            ELSIF (ce_fsm = '1') AND (state_fsm_rw = "001") THEN -- WRITE_1

                pos_x_actuelle <= pos_x_futur;
                pos_y_actuelle <= pos_y_futur;

            END IF;
        END IF;
    END PROCESS;

    PROCESS (direction, pos_x_actuelle, pos_y_actuelle, clk)
    BEGIN
        CASE next_direction IS -- Determine la position future en fonction de la direction
            WHEN INIT =>
                pos_x_futur <= 80;
                pos_y_futur <= 120;

            WHEN UP =>
                IF (pos_y_actuelle = 0) THEN
                    pos_x_futur <= pos_x_actuelle;
                    pos_y_futur <= pos_y_actuelle;
                ELSE
                    pos_x_futur <= pos_x_actuelle;
                    pos_y_futur <= pos_y_actuelle - 1;
                END IF;

            WHEN DOWN =>
                IF (pos_y_actuelle = hauteur - 1) THEN
                    pos_x_futur <= pos_x_actuelle;
                    pos_y_futur <= pos_y_actuelle;
                ELSE
                    pos_x_futur <= pos_x_actuelle;
                    pos_y_futur <= pos_y_actuelle + 1;
                END IF;

            WHEN LEFT =>
                IF (pos_x_actuelle = 0) THEN
                    pos_x_futur <= pos_x_actuelle;
                    pos_y_futur <= pos_y_actuelle;
                ELSE
                    pos_x_futur <= pos_x_actuelle - 1;
                    pos_y_futur <= pos_y_actuelle;
                END IF;

            WHEN RIGHT =>
                IF (pos_x_actuelle = largeur - 1) THEN
                    pos_x_futur <= pos_x_actuelle;
                    pos_y_futur <= pos_y_actuelle;
                ELSE
                    pos_x_futur <= pos_x_actuelle + 1;
                    pos_y_futur <= pos_y_actuelle;
                END IF;

            WHEN LOSE =>
                pos_y_futur <= pos_y_actuelle;
                pos_x_futur <= pos_x_actuelle;

            WHEN OTHERS =>
                pos_y_futur <= 0;
                pos_x_futur <= 0;

        END CASE;
    END PROCESS;

    PROCESS (direction, b_up, b_down, b_left, b_right, state_fsm_rw)
    BEGIN
        next_direction <= direction;

        CASE (direction) IS -- Determine la prochaine direction en fonction des boutons
            WHEN INIT =>
                IF (state_fsm_rw = "000") THEN -- READ_1
                    next_direction <= RIGHT;
                ELSE
                    next_direction <= INIT;
                END IF;

            WHEN UP =>
                IF (b_left = '1') THEN
                    next_direction <= LEFT;
                ELSIF (b_right = '1') THEN
                    next_direction <= RIGHT;
                ELSIF (state_fsm_rw = "100") THEN
                    next_direction <= INIT;
                ELSIF (state_fsm_rw = "110") THEN
                    next_direction <= LOSE;
                END IF;

            WHEN DOWN =>
                IF (b_left = '1') THEN
                    next_direction <= LEFT;
                ELSIF (b_right = '1') THEN
                    next_direction <= RIGHT;
                ELSIF (state_fsm_rw = "100") THEN
                    next_direction <= INIT;
                ELSIF (state_fsm_rw = "110") THEN
                    next_direction <= LOSE;
                END IF;

            WHEN LEFT =>
                IF (b_up = '1') THEN
                    next_direction <= UP;
                ELSIF (b_down = '1') THEN
                    next_direction <= DOWN;
                ELSIF (state_fsm_rw = "100") THEN
                    next_direction <= INIT;
                ELSIF (state_fsm_rw = "110") THEN
                    next_direction <= LOSE;
                END IF;

            WHEN RIGHT =>
                IF (b_up = '1') THEN
                    next_direction <= UP;
                ELSIF (b_down = '1') THEN
                    next_direction <= DOWN;
                ELSIF (state_fsm_rw = "100") THEN
                    next_direction <= INIT;
                ELSIF (state_fsm_rw = "110") THEN
                    next_direction <= LOSE;
                END IF;

            WHEN LOSE =>
                IF (state_fsm_rw = "100") THEN
                    next_direction <= INIT;
                ELSE
                    next_direction <= LOSE;
                END IF;

            WHEN OTHERS =>
                next_direction <= INIT;
        END CASE;
    END PROCESS;


J1_x <= STD_LOGIC_VECTOR(to_unsigned(pos_x_futur, 9)) WHEN state_fsm_rw = "000" -- READ_1
       ELSE STD_LOGIC_VECTOR(to_unsigned(pos_x_actuelle, 9));

J1_y <= STD_LOGIC_VECTOR(to_unsigned(pos_y_futur, 8)) WHEN state_fsm_rw = "000" -- READ_1
       ELSE STD_LOGIC_VECTOR(to_unsigned(pos_y_actuelle, 8));


END Behavioral;