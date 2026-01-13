-------------------------------------------------------------------------------
-- Bitmap VGA display with 640x480 pixel resolution
--
-- Provides a bitmap interface for VGA display
-- input clock must be a multiple of 25MHz
-- Frequency must be indicated using the CLK_FREQ generic
--
-- RAM_BPP is the number of bits per pixel in memory
-- HARD_BPP is the actual number of bits for the VGA interface.
--   RAM_BPP <= HARD_BPP
-- if INDEXED = 0, output colors are decoded from the binary value in RAM,
-- if INDEXED = 1, output colors are defined according to a lookup table (palette)
-- if READBACK = 0, the graphic RAM read operation is disabled. This makes it
-- possible so save some resources if the feature is note used.
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity VGA_bitmap_640x480 is
    generic(CLK_FREQ : integer := 100000000;         -- clk frequency, must be multiple of 25M
            RAM_BPP  : integer range 1 to 12:= 1;    -- number of bits per pixel for display
            HARD_BPP : integer range 1 to 16:=12;    -- number of bits per pixel actually available in hardware
            INDEXED  : integer range 0 to  1:= 0;    -- colors are indexed (1) or directly coded from RAM value (0)
            READBACK : integer range 0 to  1:= 1);   -- readback enabled ? might save some resources
    port(clk          : in  std_logic;
         reset        : in  std_logic;
         VGA_hs       : out std_logic;   -- horisontal vga syncr.
         VGA_vs       : out std_logic;   -- vertical vga syncr.
         VGA_color    : out std_logic_vector(HARD_BPP - 1 downto 0);

         pixel_x      : in  std_logic_vector(9 downto 0);
         pixel_y      : in  std_logic_vector(8 downto 0);
         data_in      : in  std_logic_vector( RAM_BPP - 1 downto 0);
         data_write   : in  std_logic;
         data_read    : in  std_logic:='0';
         data_rout    : out std_logic;
         data_out     : out std_logic_vector( RAM_BPP - 1 downto 0);

         end_of_frame : out std_logic;

         palette_w    : in  std_logic := '0';
         palette_idx  : in  std_logic_vector( RAM_BPP - 1 downto 0) := (others => '0');
         palette_val  : in  std_logic_vector(HARD_BPP - 1 downto 0) := (others => '0'));
end VGA_bitmap_640x480;

architecture Behavioral of VGA_bitmap_640x480 is

    signal VGA_hs_dly : std_logic_vector(2 downto 0);
    signal VGA_vs_dly : std_logic_vector(2 downto 0);

    -- Graphic RAM type. this object is the content of the displayed image
    -- to save memory resources, it is divided in two actual RAMS :
    --   screen0 : 256k x RAM_BPP : uses 8 BRAM36/pixel bit
    --   screen1 :  64k x RAM_BPP : uses 2 BRAM36/pixel bit
    type GRAM0 is array (0 to 262143) of std_logic_vector(RAM_BPP-1 downto 0);
    type GRAM1 is array (0 to  65535) of std_logic_vector(RAM_BPP-1 downto 0);
    signal screen0       : GRAM0;                           -- the memory representation of the image
    signal screen1       : GRAM1;                           -- the memory representation of the image

    signal preRAMaddr_x  : std_logic_vector(18 downto 0);
    signal preRAMaddr_y1 : std_logic_vector(18 downto 0);
    signal preRAMaddr_y5 : std_logic_vector(18 downto 0);

    signal RAM_addr      : std_logic_vector(18 downto 0):=(others => '0');   -- address used for RAM user access (synchronous from pixel_x and pixel_y)
    signal RAM_addr0     : std_logic_vector(17 downto 0):=(others => '0');   -- address used for RAM0 user access (synchronous from RAM_addr)
    signal RAM_addr1     : std_logic_vector(15 downto 0):=(others => '0');   -- address used for RAM1 user access (synchronous from RAM_addr)

    signal delayed_wr    : std_logic;                       -- write order (synchronous to RAM_addr)
    signal delayed_wr0   : std_logic;                       -- write order to GRAM0 (synchronous to RAM_addr0)
    signal delayed_wr1   : std_logic;                       -- write order to GRAM1 (synchronous to RAM_addr1)

    signal delayed_rd    : std_logic;                       -- read order (synchronous to RAM_addr)
    signal delayed_rd0   : std_logic;                       -- read order (synchronous to RAM_addr0)
    signal delayed_rd1   : std_logic;                       -- read order (synchronous to RAM_addr1)
    signal delayed_rdp0  : std_logic;                       -- read order (synchronous to data_out0)
    signal delayed_rdp1  : std_logic;                       -- read order (synchronous to data_out0)

    signal pixel_in_dly0 : std_logic_vector(RAM_BPP-1 downto 0); -- pixel data to write to memory (synchronous to RAM_addr)
    signal pixel_in_dly1 : std_logic_vector(RAM_BPP-1 downto 0); -- pixel data to write to memory (synchronous to RAM_addr0 or RAM_addr1)
    signal data_out0 : std_logic_vector(RAM_BPP-1 downto 0);     -- output of GRAM0
    signal data_out1 : std_logic_vector(RAM_BPP-1 downto 0);     -- output of GRAM1

    type palette_t is array (0 to 2**RAM_BPP-1) of std_logic_vector(HARD_BPP-1 downto 0);
    signal palette       : palette_t;

    constant clk_prediv   : integer := CLK_FREQ / 25000000 - 1;
    constant H_pixsize    : integer := 639;    -- horizontal display size - 1
    constant H_frontporch : integer :=  15;    -- horizontal front porch value - 1
    constant H_syncpulse  : integer :=  95;    -- horizontal sync pulse value - 1
    constant H_backporch  : integer :=  47;    -- horizontal back porch value - 1
    constant H_sync_pos   : std_logic := '0';  -- horizontal sync pulse polarity
    constant V_pixsize    : integer := 479;    -- vertical display size - 1
    constant V_frontporch : integer :=   9;    -- vertical front porch value - 1
    constant V_syncpulse  : integer :=   1;    -- vertical sync pulse value - 1
    constant V_backporch  : integer :=  32;    -- vertical back porch value - 1
    constant V_sync_pos   : std_logic := '0';  -- vertical sync pulse polarity

    signal clk_prediv_cnt : integer range 0 to clk_prediv;   -- for clock predivision
    signal clk_prediv_en  : std_logic;                      -- pixel counter enable

    type sync_FSM_t is (state_back_porch,
                        state_sync,
                        state_front_porch,
                        state_display);

    signal Hsync_state : sync_FSM_t;
    signal Vsync_state : sync_FSM_t;
    signal Hsync_cnt   : integer range 0 to 639;
    signal Vsync_cnt   : integer range 0 to 479;
    signal new_line_en : boolean;

    signal local_frame_end  : std_logic;
    signal frame_parity     : std_logic;

    signal pixout           : std_logic_vector( 2 downto 0);                  -- shift reg to keep info syncrhonized with pixel value. '1' means pixel is displayed
    signal pix_read_addr    : std_logic_vector(18 downto 0):=(others => '0'); -- the address at which next pixel should be read for display
    signal pix_read_addr0   : std_logic_vector(17 downto 0):=(others => '0'); -- the RAM0 address at which next pixel should be read for display
    signal pix_read_addr1   : std_logic_vector(15 downto 0):=(others => '0'); -- the RAM1 address at which next pixel should be read for display
    signal pix_read_MSBdly  : std_logic_vector(1 downto 0);                   -- MSB of RAM read address to folow pipeline
    signal next_pixel0      : std_logic_vector(RAM_BPP-1 downto 0);
    signal next_pixel1      : std_logic_vector(RAM_BPP-1 downto 0);
    signal next_pixel       : std_logic_vector(RAM_BPP-1 downto 0);


    function fill(vect_in : std_logic_vector; outsize : integer) return std_logic_vector is
            variable idx      : integer;
            variable vect_out : std_logic_vector(outsize-1 downto 0);
        begin
            idx := vect_in'left;
            for odx in outsize-1 downto 0 loop
                vect_out(odx) := vect_in(idx);
                if idx>vect_in'right then
                    idx := idx - 1;
                else
                    idx := vect_in'left;
                end if;
            end loop;
            return vect_out;
        end function;

    signal i_palette_w    : std_logic;
    signal i_palette_idx  : std_logic_vector( RAM_BPP - 1 downto 0);
    signal i_palette_val  : std_logic_vector(HARD_BPP - 1 downto 0);


begin


    preRAMaddr_x  <= "000000000" & pixel_x;
    preRAMaddr_y5 <= "0" & pixel_y & "000000000";
    preRAMaddr_y1 <= "000" & pixel_y & "0000000";

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                RAM_addr <= (others => '1');
            elsif to_integer(unsigned(pixel_x)) > 639 then
                RAM_addr <= (others => '1');
            elsif to_integer(unsigned(pixel_y)) > 479 then
                RAM_addr <= (others => '1');
            else
                RAM_addr <= std_logic_vector(unsigned(preRAMaddr_x) + unsigned(preRAMaddr_y5) + unsigned(preRAMaddr_y1));
            end if;
            delayed_wr    <= data_write;
            if READBACK /= 0 then
                delayed_rd    <= data_read;
            else
                delayed_rd    <= '0';
            end if;
            pixel_in_dly0 <= data_in;

            RAM_addr0     <= RAM_addr(17 downto 0);
            delayed_wr0   <= delayed_wr and not RAM_addr(18);
            delayed_rd0   <= delayed_rd and not RAM_addr(18);
            RAM_addr1     <= RAM_addr(15 downto 0);
            delayed_wr1   <= delayed_wr and RAM_addr(18) and not RAM_addr(17) and not RAM_addr(16);
            delayed_rd1   <= delayed_rd and RAM_addr(18) and not RAM_addr(17) and not RAM_addr(16);
            pixel_in_dly1 <= pixel_in_dly0;

            delayed_rdp0  <= delayed_rd0;
            delayed_rdp1  <= delayed_rd1;

        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pix_read_addr <= (others => '0');
            elsif Vsync_state = state_sync then
                pix_read_addr <= (others => '0');
            elsif clk_prediv_en  = '1' and Vsync_state = state_display and Hsync_state = state_display then
                pix_read_addr <= std_logic_vector(unsigned(pix_read_addr)+1);
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            -- if reset = '1' then
            --     pix_read_addr0 <= (others => '0');
            --     pix_read_addr1 <= (others => '0');
            -- else
                pix_read_addr0     <= pix_read_addr(17 downto 0);
                pix_read_addr1     <= pix_read_addr(15 downto 0);
                pix_read_MSBdly(0) <= pix_read_addr(18);
                pix_read_MSBdly(1) <= pix_read_MSBdly(0);
            -- end if;
        end if;
    end process;


    -- This process performs data access (read and write) to the memory
    memory_management : process(clk)
    begin
       if rising_edge(clk) then
          next_pixel0 <= screen0(to_integer(unsigned(pix_read_addr0)));
          next_pixel1 <= screen1(to_integer(unsigned(pix_read_addr1)));

          data_out0   <= screen0(to_integer(unsigned(RAM_addr0)));
          data_out1   <= screen1(to_integer(unsigned(RAM_addr1)));
          if delayed_wr0 = '1' then
             screen0(to_integer(unsigned(RAM_addr0))) <= pixel_in_dly1;
          end if;
          if delayed_wr1 = '1' then
             screen1(to_integer(unsigned(RAM_addr1))) <= pixel_in_dly1;
          end if;
       end if;
    end process;

    -- data output process
    dout_mgr : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                data_out  <= (others => '0');
                data_rout <= '0';
            elsif delayed_rdp0 = '1' then
                data_out  <= data_out0;
                data_rout <= '1';
            elsif delayed_rdp1 = '1' then
                data_out  <= data_out1;
                data_rout <= '1';
            else
                data_out  <= (others => '0');
                data_rout <= '0';
            end if;
       end if;
    end process;

---------------------------------------------------------------------

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            clk_prediv_cnt <= clk_prediv;
            clk_prediv_en  <= '0';
        elsif clk_prediv_cnt = 0 then
            clk_prediv_cnt <= clk_prediv;
            clk_prediv_en  <= '1';
        else
            clk_prediv_cnt <= clk_prediv_cnt - 1;
            clk_prediv_en  <= '0';
        end if;
    end if;
end process;

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            Hsync_state <= state_front_porch;
            Hsync_cnt   <= H_frontporch-1;
        elsif clk_prediv_en  = '1' then
            case Hsync_state is
                when state_back_porch  =>
                    if Hsync_cnt = H_backporch then
                        Hsync_cnt   <= 0;
                        Hsync_state <= state_display;
                    else
                        Hsync_cnt   <= Hsync_cnt + 1;
                    end if;
                when state_sync        =>
                    if Hsync_cnt = H_syncpulse then
                        Hsync_cnt   <= 0;
                        Hsync_state <= state_back_porch;
                    else
                        Hsync_cnt   <= Hsync_cnt + 1;
                    end if;
                when state_front_porch =>
                    if Hsync_cnt = H_frontporch then
                        Hsync_cnt   <= 0;
                        Hsync_state <= state_sync;
                    else
                        Hsync_cnt   <= Hsync_cnt + 1;
                    end if;
                when state_display     =>
                    if Hsync_cnt = H_pixsize then
                        Hsync_cnt   <= 0;
                        Hsync_state <= state_front_porch;
                    else
                        Hsync_cnt   <= Hsync_cnt + 1;
                    end if;
            end case;
        end if;
    end if;
end process;

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            new_line_en <= False;
        elsif clk_prediv = 0 and Hsync_state = state_sync and Hsync_cnt = H_syncpulse-1 then
            new_line_en <= True;
        elsif clk_prediv /= 0 and clk_prediv_cnt = 0 and Hsync_state = state_sync and Hsync_cnt = H_syncpulse then
            new_line_en <= True;
        else
            new_line_en <= False;
        end if;
    end if;
end process;


process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            VGA_hs_dly <= (others => '1');
            VGA_hs     <= not H_sync_pos;
        elsif Hsync_state = state_sync then
            VGA_hs_dly(0)          <= H_sync_pos;
            VGA_hs_dly(2 downto 1) <= VGA_hs_dly(1 downto 0);
            VGA_hs                 <= VGA_hs_dly(2);
        else
            VGA_hs_dly(0)          <= not H_sync_pos;
            VGA_hs_dly(2 downto 1) <= VGA_hs_dly(1 downto 0);
            VGA_hs                 <= VGA_hs_dly(2);
        end if;
    end if;
end process;


end_of_frame <= local_frame_end;


process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            local_frame_end <= '1';
        elsif Vsync_state = state_display and Vsync_cnt = V_pixsize and Hsync_state = state_front_porch then
            local_frame_end <= '1';
        else
            local_frame_end <= '0';
        end if;
    end if;
end process;

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            Vsync_state     <= state_front_porch;
            Vsync_cnt       <= V_frontporch-1;
        elsif new_line_en then
            case Vsync_state is
                when state_back_porch  =>
                    if Vsync_cnt = V_backporch then
                        Vsync_cnt   <= 0;
                        Vsync_state <= state_display;
                    else
                        Vsync_cnt   <= Vsync_cnt + 1;
                    end if;
                when state_sync        =>
                    if Vsync_cnt = V_syncpulse then
                        Vsync_cnt   <= 0;
                        Vsync_state <= state_back_porch;
                    else
                        Vsync_cnt   <= Vsync_cnt + 1;
                    end if;
                when state_front_porch =>
                    if Vsync_cnt = V_frontporch then
                        Vsync_cnt   <= 0;
                        Vsync_state <= state_sync;
                    else
                        Vsync_cnt   <= Vsync_cnt + 1;
                    end if;
                when state_display     =>
                    if Vsync_cnt = V_pixsize then
                        Vsync_cnt       <= 0;
                        Vsync_state     <= state_front_porch;
                    else
                        Vsync_cnt   <= Vsync_cnt + 1;
                    end if;
            end case;
        end if;
    end if;
end process;


process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            VGA_vs_dly <= (others => '1');
            VGA_vs     <= not V_sync_pos;
        elsif Vsync_state = state_sync then
            VGA_vs_dly(0)          <= V_sync_pos;
            VGA_vs_dly(2 downto 1) <= VGA_vs_dly(1 downto 0);
            VGA_vs                 <= VGA_vs_dly(2);
        else
            VGA_vs_dly(0)          <= not V_sync_pos;
            VGA_vs_dly(2 downto 1) <= VGA_vs_dly(1 downto 0);
            VGA_vs                 <= VGA_vs_dly(2);
        end if;
    end if;
end process;



process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            next_pixel <= (others => '0');
        elsif pix_read_MSBdly(1) = '0' then
            next_pixel <= next_pixel0;
        else
            next_pixel <= next_pixel1;
        end if;
        if Vsync_state = state_display and Hsync_state = state_display then
            pixout(0) <= '1';
        else
            pixout(0) <= '0';
        end if;
        pixout(2 downto 1) <= pixout(1 downto 0);

    end if;
end process;


process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            VGA_color <= (others => '0');
        elsif pixout(2) = '0' then
            VGA_color <= (others => '0');
        elsif INDEXED /= 0 then
            VGA_color <= palette(to_integer(unsigned(next_pixel)));
        else

            case RAM_BPP is
                when 1 =>
                    VGA_color <= (others => next_pixel(0));
                when 2 =>
                    VGA_color(HARD_BPP-1            downto HARD_BPP-HARD_BPP/3) <= (others => (next_pixel(0) and next_pixel(1)));
                    VGA_color(HARD_BPP-HARD_BPP/3-1 downto HARD_BPP/3)          <= (others => (next_pixel(1) and not next_pixel(0)));
                    VGA_color(         HARD_BPP/3-1 downto 0)                   <= (others => (next_pixel(0) and not next_pixel(1)));
                when 3 =>
                    VGA_color(HARD_BPP-1            downto HARD_BPP-HARD_BPP/3) <= (others =>  next_pixel(2));
                    VGA_color(HARD_BPP-HARD_BPP/3-1 downto HARD_BPP/3)          <= (others =>  next_pixel(1));
                    VGA_color(         HARD_BPP/3-1 downto 0)                   <= (others =>  next_pixel(0));
                when 4 =>
                    if next_pixel="1000" then
                        VGA_color(HARD_BPP-1)            <= '0';
                        VGA_color(HARD_BPP-HARD_BPP/3-1) <= '0';
                        VGA_color(         HARD_BPP/3-1) <= '0';
                        VGA_color(HARD_BPP-2)            <= '1';
                        VGA_color(HARD_BPP-HARD_BPP/3-2) <= '1';
                        VGA_color(         HARD_BPP/3-2) <= '1';
                        VGA_color(HARD_BPP-3            downto HARD_BPP-HARD_BPP/3) <= (others =>  '0');
                        VGA_color(HARD_BPP-HARD_BPP/3-3 downto HARD_BPP/3)          <= (others =>  '0');
                        VGA_color(         HARD_BPP/3-3 downto 0)                   <= (others =>  '0');
                    else
                        VGA_color(HARD_BPP-1)            <= next_pixel(2);
                        VGA_color(HARD_BPP-HARD_BPP/3-1) <= next_pixel(1);
                        VGA_color(         HARD_BPP/3-1) <= next_pixel(0);
                        VGA_color(HARD_BPP-2            downto HARD_BPP-HARD_BPP/3) <= (others =>  (next_pixel(2) and next_pixel(3)));
                        VGA_color(HARD_BPP-HARD_BPP/3-2 downto HARD_BPP/3)          <= (others =>  (next_pixel(1) and next_pixel(3)));
                        VGA_color(         HARD_BPP/3-2 downto 0)                   <= (others =>  (next_pixel(0) and next_pixel(3)));
                    end if;
                when 6 =>
                    VGA_color(HARD_BPP-1            downto HARD_BPP-HARD_BPP/3) <= fill(next_pixel(5 downto 4),  HARD_BPP   /3);
                    VGA_color(HARD_BPP-HARD_BPP/3-1 downto HARD_BPP/3)          <= fill(next_pixel(3 downto 2), (HARD_BPP+2)/3);
                    VGA_color(         HARD_BPP/3-1 downto 0)                   <= fill(next_pixel(1 downto 0),  HARD_BPP   /3);
                when 7 =>
                    VGA_color(HARD_BPP-1            downto HARD_BPP-HARD_BPP/3) <= fill(next_pixel(7 downto 5),  HARD_BPP   /3);
                    VGA_color(HARD_BPP-HARD_BPP/3-1 downto HARD_BPP/3)          <= fill(next_pixel(4 downto 2), (HARD_BPP+2)/3);
                    VGA_color(         HARD_BPP/3-1 downto 0)                   <= fill(next_pixel(1 downto 0),  HARD_BPP   /3);
                when 9 =>
                    VGA_color(HARD_BPP-1            downto HARD_BPP-HARD_BPP/3) <= fill(next_pixel(8 downto 6),  HARD_BPP   /3);
                    VGA_color(HARD_BPP-HARD_BPP/3-1 downto HARD_BPP/3)          <= fill(next_pixel(5 downto 3), (HARD_BPP+2)/3);
                    VGA_color(         HARD_BPP/3-1 downto 0)                   <= fill(next_pixel(2 downto 0),  HARD_BPP   /3);
                when 10 =>
                    VGA_color(HARD_BPP-1            downto HARD_BPP-HARD_BPP/3) <= fill(next_pixel(9 downto 7),  HARD_BPP   /3);
                    VGA_color(HARD_BPP-HARD_BPP/3-1 downto HARD_BPP/3)          <= fill(next_pixel(6 downto 3), (HARD_BPP+2)/3);
                    VGA_color(         HARD_BPP/3-1 downto 0)                   <= fill(next_pixel(2 downto 0),  HARD_BPP   /3);
                when 12 =>
                    VGA_color(HARD_BPP-1            downto HARD_BPP-HARD_BPP/3) <= fill(next_pixel(11 downto 8),  HARD_BPP   /3);
                    VGA_color(HARD_BPP-HARD_BPP/3-1 downto HARD_BPP/3)          <= fill(next_pixel( 7 downto 4), (HARD_BPP+2)/3);
                    VGA_color(         HARD_BPP/3-1 downto 0)                   <= fill(next_pixel( 3 downto 0),  HARD_BPP   /3);
                when others =>
                    VGA_color <= (others => '0');
            end case;
      end if;
   end if;
end process;

process(clk)
begin
    if rising_edge(clk) then
        if INDEXED /= 0 then
            i_palette_w   <= palette_w;
            i_palette_idx <= palette_idx;
            i_palette_val <= palette_val;
            if i_palette_w = '1' then
                palette(to_integer(unsigned(i_palette_idx))) <= i_palette_val;
            end if;
        end if;
    end if;
end process;


----------------------

end Behavioral;
