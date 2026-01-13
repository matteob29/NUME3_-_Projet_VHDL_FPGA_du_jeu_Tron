library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_init is
end tb_init;

architecture Behavioral of tb_init is

    -- Paramètres réduits pour test plus court (modifiable)
    constant hauteur_tb : integer := 240;   -- mettre 240 pour test réel
    constant largeur_tb : integer := 320;   -- mettre 320 pour test réel

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '0';
    signal init      : std_logic := '0';

    signal data_in   : std_logic_vector(1 downto 0);
    signal pixel_x   : std_logic_vector(8 downto 0);
    signal pixel_y   : std_logic_vector(7 downto 0);
    signal end_init  : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    --------------------------------------------------------------------
    -- Instance du DUT
    --------------------------------------------------------------------
    DUT : entity work.Tableau_init
        generic map (
            hauteur => hauteur_tb,
            largeur => largeur_tb
        )
        port map (
            init      => init,
            clk       => clk,
            rst       => rst,
            data_in   => data_in,
            pixel_x   => pixel_x,
            pixel_y   => pixel_y,
            end_init  => end_init
        );

    --------------------------------------------------------------------
    -- Génération horloge
    --------------------------------------------------------------------
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;


    --------------------------------------------------------------------
    -- Stimuli
    --------------------------------------------------------------------
    stim_proc : process
    begin
        ----------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------
        rst <= '1';
        init <= '0';
        wait for 50 ns;

        rst <= '0';
        wait for 50 ns;

        ----------------------------------------------------------------
        -- Lancement de l'initialisation
        ----------------------------------------------------------------
        init <= '1';
        wait for 20 ns;
        init <= '0';

        ----------------------------------------------------------------
        -- Attendre la fin d'init
        ----------------------------------------------------------------
        wait;

    end process;

end Behavioral;