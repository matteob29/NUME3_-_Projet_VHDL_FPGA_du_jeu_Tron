----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/10/2025 09:43:23 AM
-- Design Name: 
-- Module Name: tb_fsm_position - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_fsm_position is
end tb_fsm_position;

architecture Behavioral of tb_fsm_position is
    -- Déclaration des signaux pour le testbench
    signal clk : STD_LOGIC := '0';
    signal ce_mvt : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal j : STD_LOGIC := '0';
    signal b_up : STD_LOGIC := '0';
    signal b_down : STD_LOGIC := '0';
    signal b_left : STD_LOGIC := '0';
    signal b_right : STD_LOGIC := '0';
    signal in_fin : STD_LOGIC := '0';
    signal fin_init : std_logic:='0';
    signal out_x : STD_LOGIC_VECTOR(8 downto 0);
    signal out_y : STD_LOGIC_VECTOR(7 downto 0);

    -- Constante pour la période de l'horloge
    constant clk_period : time := 10 ns;

begin
    -- Instanciation du module à tester
    uut: entity work.fsm_position
        port map (
            clk => clk,
            ce_mvt => ce_mvt,
            rst => rst,
            j => j,
            b_up => b_up,
            b_down => b_down,
            b_left => b_left,
            b_right => b_right,
            in_fin => in_fin,
            fin_init => fin_init,
            out_x => out_x,
            out_y => out_y
        );

    -- Génération de l'horloge
    clk_process: process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Processus de test
    stim_proc: process
    begin
        -- Initialisation
        rst <= '1';
        wait for clk_period;
        rst <= '0';
        wait for 100*clk_period;
        
        fin_init <= '1';
        wait for clk_period;

        -- Test 1: Réinitialisation avec j='0'
        j <= '0';
        ce_mvt <= '1';
        wait for clk_period;
        ce_mvt <= '0';
        wait for clk_period;

        -- Test 2: Réinitialisation avec j='1'
        rst <= '1';
        j <= '1';
        wait for clk_period;
        rst <= '0';
        wait for clk_period;

        -- Test 3: Réinitialisation avec j='X' (erreur)
        rst <= '1';
        j <= '0';
        wait for clk_period;
        rst <= '0';
        wait for clk_period;

        -- Test 4: Mouvement vers la droite
        ce_mvt <= '1';
        b_right <= '1';
        wait for clk_period;
        b_right <= '0';
        wait for clk_period;

        -- Test 5: Mouvement vers le haut
        b_up <= '1';
        wait for clk_period;
        b_up <= '0';
        wait for clk_period;

        -- Test 6: Mouvement vers le bas
        b_down <= '1';
        wait for clk_period;
        b_down <= '0';
        wait for clk_period;

        -- Test 7: Mouvement vers la gauche
        b_left <= '1';
        wait for clk_period;
        b_left <= '0';
        wait for clk_period;

        -- Test 8: Changement de direction pendant le mouvement
        ce_mvt <= '1';
        b_right <= '1';
        wait for clk_period;
        b_up <= '1';
        wait for clk_period;
        b_up <= '0';
        b_right <= '0';
        wait for clk_period;

        -- Test 9: Fin du mouvement
        in_fin <= '1';
        wait for clk_period;
        in_fin <= '0';
        wait for clk_period;

        -- Fin de la simulation
        wait;
    end process;
end Behavioral;
