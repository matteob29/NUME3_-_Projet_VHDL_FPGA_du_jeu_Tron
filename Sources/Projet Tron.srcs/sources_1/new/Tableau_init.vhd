----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.11.2025 09:57:06
-- Design Name: 
-- Module Name: Tableau_init - Behavioral
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

ENTITY Tableau_init IS
    GENERIC (
        hauteur : INTEGER := 240;
        largeur : INTEGER := 320);

    PORT (
        rst : IN STD_LOGIC;
        clk : IN STD_LOGIC;
        state_fsm_rw : IN STD_LOGIC_VECTOR (2 DOWNTO 0);
        end_init : OUT STD_LOGIC;
        init_x : OUT STD_LOGIC_VECTOR (8 DOWNTO 0);
        init_y : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
        init_data_in : OUT STD_LOGIC_VECTOR (1 DOWNTO 0));
END Tableau_init;
ARCHITECTURE Behavioral OF Tableau_init IS

    SIGNAL x : INTEGER RANGE 0 TO largeur - 1;
    SIGNAL y : INTEGER RANGE 0 TO hauteur - 1;

    TYPE etat IS (IDLE, INITIALIZING, DONE);
    SIGNAL current_state : etat := IDLE;
BEGIN

    PROCESS (clk, rst)
    BEGIN
        IF rst = '1' THEN
            current_state <= IDLE;
            x <= 0;
            y <= 0;
            end_init <= '0';
        ELSIF rising_edge(clk) THEN
            CASE current_state IS

                WHEN IDLE =>
                    end_init <= '0';
                    IF state_fsm_rw = "100" THEN
                        x <= 0;
                        y <= 0;
                        current_state <= INITIALIZING;
                    END IF;

                WHEN INITIALIZING => -- Parcours de toute la grille

                    IF x = largeur - 1 THEN
                        x <= 0;
                        IF y = hauteur - 1 THEN
                            current_state <= DONE;
                        ELSE
                            y <= y + 1;
                        END IF;
                    ELSE
                        x <= x + 1;
                    END IF;

                WHEN DONE =>
                    end_init <= '1';

                    IF state_fsm_rw /= "100" THEN
                        current_state <= IDLE;
                    END IF;

                WHEN OTHERS =>
                    current_state <= IDLE;
            END CASE;
        END IF;
    END PROCESS;
    PROCESS (x, y, current_state)
    BEGIN
        IF current_state = INITIALIZING THEN -- selectionne la couleur en fonction de la position
            IF (x = 0 OR x = largeur - 1 OR y = 0 OR y = hauteur - 1) THEN
                init_data_in <= "10"; -- Contour vert

            ELSIF (x = 80 AND y = 120) THEN
                init_data_in <= "01"; -- j1 : bleu

            ELSIF (x = 240 AND y = 120) THEN
                init_data_in <= "11"; -- j2 : rouge

            ELSE
                init_data_in <= "00"; -- Fond noir
            END IF;
        ELSE
            init_data_in <= "00";
        END IF;
    END PROCESS;
    init_x <= STD_LOGIC_VECTOR(to_unsigned(x, 9));
    init_y <= STD_LOGIC_VECTOR(to_unsigned(y, 8));

END Behavioral;