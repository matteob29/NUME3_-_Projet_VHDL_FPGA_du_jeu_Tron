----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/10/2025 11:42:08 AM
-- Design Name: 
-- Module Name: top_level - Behavioral
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

ENTITY top_level IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;

        J1_up : IN STD_LOGIC;
        J1_down : IN STD_LOGIC;
        J1_left : IN STD_LOGIC;
        J1_right : IN STD_LOGIC;
        J1_center : IN STD_LOGIC;

        J2_up : IN STD_LOGIC;
        J2_down : IN STD_LOGIC;
        J2_left : IN STD_LOGIC;
        J2_right : IN STD_LOGIC;

        vga_hs : OUT STD_LOGIC;
        vga_vs : OUT STD_LOGIC;
        vga_color : OUT STD_LOGIC_VECTOR (11 DOWNTO 0);

        -- tests --
        s_J1_loses, s_J2_loses : OUT STD_LOGIC;
        s_end_init : OUT STD_LOGIC;
        s_state_fsm_rw : OUT STD_LOGIC_VECTOR (2 DOWNTO 0)
    );
END top_level;

ARCHITECTURE Behavioral OF top_level IS

    -- signaux vga_bitmap_320x240 --
    SIGNAL vga_x : STD_LOGIC_VECTOR (8 DOWNTO 0);
    SIGNAL vga_y : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL vga_data_in : STD_LOGIC_VECTOR (1 DOWNTO 0);
    SIGNAL data_out : STD_LOGIC_VECTOR (1 DOWNTO 0);
    SIGNAL data_write, data_read, data_rout : STD_LOGIC;

    -- signaux mux_3 --
    SIGNAL init_x, J1_x, J2_x : STD_LOGIC_VECTOR (8 DOWNTO 0);
    SIGNAL init_y, J1_y, J2_y : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL init_data_in, J1_data_in, J2_data_in : STD_LOGIC_VECTOR (1 DOWNTO 0);
    SIGNAL w_select : STD_LOGIC_VECTOR (1 DOWNTO 0);

    -- signaux tableau_init --
    SIGNAL end_init : STD_LOGIC;
    -- signaux fsm_rw --
    SIGNAL state_fsm_rw : STD_LOGIC_VECTOR (2 DOWNTO 0);

    -- signaux fsm_pos --
    SIGNAL J1_loses, J2_loses : STD_LOGIC;
    SIGNAL J1_b_up, J1_b_down, J1_b_left, J1_b_right, J1_b_center : STD_LOGIC;
    SIGNAL J2_b_up, J2_b_down, J2_b_left, J2_b_right : STD_LOGIC;

    -- signaux gestion_freq --
    SIGNAL ce_fsm, ce_mvt : STD_LOGIC;
BEGIN

    ----------  VGA  ----------

    VGA : ENTITY work.vga_bitmap_320x240
        PORT MAP(
            clk => clk,
            reset => rst,
            VGA_hs => vga_hs,
            VGA_vs => vga_vs,
            VGA_color => vga_color,
            pixel_x => vga_x,
            pixel_y => vga_y,
            data_in => vga_data_in,
            data_write => data_write,
            data_read => data_read,
            data_out => data_out,
            data_rout => data_rout
        );
    ----------  Mux_3  ----------

    Mux_3_9b : ENTITY work.Mux_3_9b
        PORT MAP(
            w_select => w_select,
            init_x => init_x,
            J1_x => J1_x,
            J2_x => J2_x,
            vga_x => vga_x
        );

    Mux_3_8b : ENTITY work.Mux_3_8b
        PORT MAP(
            w_select => w_select,
            init_y => init_y,
            J1_y => J1_y,
            J2_y => J2_y,
            vga_y => vga_y
        );

    Mux_3_2b : ENTITY work.Mux_3_2b
        PORT MAP(
            w_select => w_select,
            init_data_in => init_data_in,
            J1_data_in => J1_data_in,
            J2_data_in => J2_data_in,
            vga_data_in => vga_data_in
        );
    ----------  init  ----------

    Tableau_init : ENTITY work.Tableau_init
        PORT MAP(
            rst => rst,
            clk => clk,
            state_fsm_rw => state_fsm_rw,
            end_init => end_init,
            init_x => init_x,
            init_y => init_y,
            init_data_in => init_data_in
        );
    ----------  FSM  ----------

    FSM_rw : ENTITY work.fsm_rw
        PORT MAP(
            rst => rst,
            clk => clk,
            ce_fsm => ce_fsm,
            J1_loses => J1_loses,
            J2_loses => J2_loses,
            end_init => end_init,
            J1_b_center => J1_b_center,
            state_fsm_rw => state_fsm_rw,
            w_select => w_select,
            data_read => data_read,
            data_write => data_write
        );
    FSM_pos_J1 : ENTITY work.fsm_pos_J1
        PORT MAP(
            rst => rst,
            clk => clk,
            ce_fsm => ce_fsm,

            b_up => J1_b_up,
            b_down => J1_b_down,
            b_left => J1_b_left,
            b_right => J1_b_right,

            data_out => data_out,
            data_rout => data_rout,

            state_fsm_rw => state_fsm_rw,
            J1_x => J1_x,
            J1_y => J1_y,
            J1_data_in => J1_data_in,
            J1_loses => J1_loses
        );
    FSM_pos_J2 : ENTITY work.fsm_pos_J2
        PORT MAP(
            rst => rst,
            clk => clk,
            ce_fsm => ce_fsm,

            b_up => J2_b_up,
            b_down => J2_b_down,
            b_left => J2_b_left,
            b_right => J2_b_right,

            data_out => data_out,
            data_rout => data_rout,

            state_fsm_rw => state_fsm_rw,
            J2_x => J2_x,
            J2_y => J2_y,
            J2_data_in => J2_data_in,
            J2_loses => J2_loses
        );
    ----------  Gestion_freq  ----------

    gest_freq : ENTITY work.gest_freq
        PORT MAP(
            rst => rst,
            clk => clk,
            --            ce_mvt => ce_mvt,
            ce_fsm => ce_fsm
        );

    ----------  Gestion_freq  ----------

    Reg_in_J1_up : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J1_up,
            S => J1_b_up
        );

    Reg_in_J1_down : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J1_down,
            S => J1_b_down
        );
    Reg_in_J1_left : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J1_left,
            S => J1_b_left
        );

    Reg_in_J1_right : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J1_right,
            S => J1_b_right
        );

    Reg_in_J1_center : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J1_center,
            S => J1_b_center
        );
    Reg_in_J2_up : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J2_up,
            S => J2_b_up
        );

    Reg_in_J2_down : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J2_down,
            S => J2_b_down
        );
    Reg_in_J2_left : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J2_left,
            S => J2_b_left
        );

    Reg_in_J2_right : ENTITY work.Reg_In
        PORT MAP(
            clk => clk,
            E => J2_right,
            S => J2_b_right
        );
    ----------  Tests  ----------
    s_end_init <= end_init;
    s_state_fsm_rw <= state_fsm_rw;
    s_J1_loses <= J1_loses;
    s_J2_loses <= J2_loses;
END Behavioral;