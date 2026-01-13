library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_fsm_rw is
end tb_fsm_rw;

architecture Behavioral of tb_fsm_rw is
    -- Déclaration des signaux pour le testbench
    signal clk : STD_LOGIC := '0';
    signal ce_fsm : STD_LOGIC := '0';
    signal rst : STD_LOGIC := '0';
    signal lose : STD_LOGIC := '0';
    signal fin_init : STD_LOGIC := '0';
    signal in_x_1 : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');
    signal in_y_1 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal in_x_2 : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');
    signal in_y_2 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal out_x : STD_LOGIC_VECTOR(8 downto 0);
    signal out_y : STD_LOGIC_VECTOR(7 downto 0);
    signal data_w : STD_LOGIC_VECTOR(1 downto 0);
    signal read : STD_LOGIC;
    signal write : STD_LOGIC;
    signal init_out : STD_LOGIC;
    signal out_fin : STD_LOGIC;
    signal j_out : STD_LOGIC;

    -- Constante pour la période de l'horloge
    constant clk_period : time := 10 ns;

begin
    -- Instanciation du module à tester
    uut: entity work.fsm_rw
        port map (
            clk => clk,
            ce_fsm => ce_fsm,
            rst => rst,
            lose => lose,
            fin_init => fin_init,
            in_x_1 => in_x_1,
            in_y_1 => in_y_1,
            in_x_2 => in_x_2,
            in_y_2 => in_y_2,
            out_x => out_x,
            out_y => out_y,
            data_w => data_w,
            read => read,
            write => write,
            init_out => init_out,
            out_fin => out_fin,
            j_out => j_out
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
        wait for clk_period;

        -- Test 1: Initialisation
        ce_fsm <= '1';
        fin_init <= '0';
        wait for clk_period;
        fin_init <= '1';
        wait for clk_period;

        -- Test 2: Lecture des coordonnées du joueur 1
        in_x_1 <= std_logic_vector(to_unsigned(80, 9));
        in_y_1 <= std_logic_vector(to_unsigned(180, 8));
        wait for clk_period;

        -- Test 3: Écriture des coordonnées du joueur 1
        wait for clk_period;

        -- Test 4: Lecture des coordonnées du joueur 2
        in_x_2 <= std_logic_vector(to_unsigned(240, 9));
        in_y_2 <= std_logic_vector(to_unsigned(180, 8));
        wait for clk_period;

        -- Test 5: Écriture des coordonnées du joueur 2
        wait for clk_period;

        -- Test 6: Perte du jeu
        lose <= '1';
        wait for clk_period;
        lose <= '0';
        wait for clk_period;

        -- Fin de la simulation
        wait;
    end process;
end Behavioral;