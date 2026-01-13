----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/24/2025 09:59:29 AM
-- Design Name: 
-- Module Name: tb_top - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_top is
--  Port ( );
end tb_top;

architecture Behavioral of tb_top is

signal clk,rst,sig_up_1,sig_up_2,sig_left_1,sig_left_2,sig_down_1,sig_down_2,sig_right_1,sig_right_2,sig_vga_hs,sig_vga_vs : std_logic;
signal sig_vga_color : std_logic_vector (11 downto 0);

begin

top_level : entity work.top_level
    Port map ( clk => clk,
               rst => rst,
               up_1 => sig_up_1,
               up_2 => sig_up_2,
               left_1 => sig_left_1,
               left_2 => sig_left_2,
               down_1 => sig_down_1,
               down_2 => sig_down_2,
               right_1 => sig_right_1,
               right_2 => sig_right_2,
               vga_hs => sig_vga_hs,
               vga_vs => sig_vga_vs,
               vga_color => sig_vga_color
    ); 

 clk_process: process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
end process;

    -- Processus de test
stim_proc: process
    begin
    
    rst <= '1', '0' after 127 ns;
    
end process; 

end Behavioral;
