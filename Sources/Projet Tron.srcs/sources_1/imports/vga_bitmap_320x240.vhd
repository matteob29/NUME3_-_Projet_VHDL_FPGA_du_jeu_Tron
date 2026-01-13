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
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY VGA_bitmap_320x240 IS
    GENERIC (
        CLK_FREQ : INTEGER := 100000000; -- clk frequency, must be multiple of 25M
        RAM_BPP : INTEGER RANGE 1 TO 12 := 2; -- number of bits per pixel for display
        HARD_BPP : INTEGER RANGE 1 TO 16 := 12; -- number of bits per pixel actually available in hardware
        INDEXED : INTEGER RANGE 0 TO 1 := 0; -- colors are indexed (1) or directly coded from RAM value (0)
        READBACK : INTEGER RANGE 0 TO 1 := 1); -- readback enabled ? might save some resources
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        VGA_hs : OUT STD_LOGIC; -- horisontal vga syncr.
        VGA_vs : OUT STD_LOGIC; -- vertical vga syncr.
        VGA_color : OUT STD_LOGIC_VECTOR(HARD_BPP - 1 DOWNTO 0);

        pixel_x : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
        pixel_y : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        data_in : IN STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0);
        data_write : IN STD_LOGIC;
        data_read : IN STD_LOGIC := '0';
        data_rout : OUT STD_LOGIC;
        data_out : OUT STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0);

        end_of_frame : OUT STD_LOGIC;

        palette_w : IN STD_LOGIC := '0';
        palette_idx : IN STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0) := (OTHERS => '0');
        palette_val : IN STD_LOGIC_VECTOR(HARD_BPP - 1 DOWNTO 0) := (OTHERS => '0'));
END VGA_bitmap_320x240;

ARCHITECTURE Behavioral OF VGA_bitmap_320x240 IS

    SIGNAL VGA_hs_dly : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL VGA_vs_dly : STD_LOGIC_VECTOR(2 DOWNTO 0);

    -- Graphic RAM type. this object is the content of the displayed image
    -- to save memory resources, it is divided in two actual RAMS :
    --   screen0 : 256k x RAM_BPP : uses 8 BRAM36/pixel bit
    --   screen1 :  64k x RAM_BPP : uses 2 BRAM36/pixel bit
    TYPE GRAM0 IS ARRAY (0 TO 262143) OF STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0);
    TYPE GRAM1 IS ARRAY (0 TO 65535) OF STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0);
    SIGNAL screen0 : GRAM0; -- the memory representation of the image
    SIGNAL screen1 : GRAM1; -- the memory representation of the image

    SIGNAL preRAMaddr_x : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL preRAMaddr_y1 : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL preRAMaddr_y5 : STD_LOGIC_VECTOR(16 DOWNTO 0);

    SIGNAL RAM_addr : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0'); -- address used for RAM user access (synchronous from pixel_x and pixel_y)
    SIGNAL RAM_addr0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0'); -- address used for RAM0 user access (synchronous from RAM_addr)
    SIGNAL RAM_addr1 : STD_LOGIC_VECTOR(13 DOWNTO 0) := (OTHERS => '0'); -- address used for RAM1 user access (synchronous from RAM_addr)

    SIGNAL delayed_wr : STD_LOGIC; -- write order (synchronous to RAM_addr)
    SIGNAL delayed_wr0 : STD_LOGIC; -- write order to GRAM0 (synchronous to RAM_addr0)
    SIGNAL delayed_wr1 : STD_LOGIC; -- write order to GRAM1 (synchronous to RAM_addr1)

    SIGNAL delayed_rd : STD_LOGIC; -- read order (synchronous to RAM_addr)
    SIGNAL delayed_rd0 : STD_LOGIC; -- read order (synchronous to RAM_addr0)
    SIGNAL delayed_rd1 : STD_LOGIC; -- read order (synchronous to RAM_addr1)
    SIGNAL delayed_rdp0 : STD_LOGIC; -- read order (synchronous to data_out0)
    SIGNAL delayed_rdp1 : STD_LOGIC; -- read order (synchronous to data_out0)

    SIGNAL pixel_in_dly0 : STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0); -- pixel data to write to memory (synchronous to RAM_addr)
    SIGNAL pixel_in_dly1 : STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0); -- pixel data to write to memory (synchronous to RAM_addr0 or RAM_addr1)
    SIGNAL data_out0 : STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0); -- output of GRAM0
    SIGNAL data_out1 : STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0); -- output of GRAM1

    TYPE palette_t IS ARRAY (0 TO 2 ** RAM_BPP - 1) OF STD_LOGIC_VECTOR(HARD_BPP - 1 DOWNTO 0);
    SIGNAL palette : palette_t;

    CONSTANT clk_prediv : INTEGER := CLK_FREQ / 25000000 - 1;
    CONSTANT H_pixsize : INTEGER := 639; -- horizontal display size - 1
    CONSTANT H_frontporch : INTEGER := 15; -- horizontal front porch value - 1
    CONSTANT H_syncpulse : INTEGER := 95; -- horizontal sync pulse value - 1
    CONSTANT H_backporch : INTEGER := 47; -- horizontal back porch value - 1
    CONSTANT H_sync_pos : STD_LOGIC := '0'; -- horizontal sync pulse polarity
    CONSTANT V_pixsize : INTEGER := 479; -- vertical display size - 1
    CONSTANT V_frontporch : INTEGER := 9; -- vertical front porch value - 1
    CONSTANT V_syncpulse : INTEGER := 1; -- vertical sync pulse value - 1
    CONSTANT V_backporch : INTEGER := 32; -- vertical back porch value - 1
    CONSTANT V_sync_pos : STD_LOGIC := '0'; -- vertical sync pulse polarity

    SIGNAL clk_prediv_cnt : INTEGER RANGE 0 TO clk_prediv; -- for clock predivision
    SIGNAL clk_prediv_en : STD_LOGIC; -- pixel counter enable

    TYPE sync_FSM_t IS (state_back_porch,
        state_sync,
        state_front_porch,
        state_display);

    SIGNAL Hsync_state : sync_FSM_t;
    SIGNAL Vsync_state : sync_FSM_t;
    SIGNAL Hsync_cnt : INTEGER RANGE 0 TO 639;
    SIGNAL Vsync_cnt : INTEGER RANGE 0 TO 479;
    SIGNAL new_line_en : BOOLEAN;

    SIGNAL local_frame_end : STD_LOGIC;
    SIGNAL frame_parity : STD_LOGIC;

    SIGNAL pixout : STD_LOGIC_VECTOR(2 DOWNTO 0); -- shift reg to keep info syncrhonized with pixel value. '1' means pixel is displayed
    SIGNAL pix_read_addr : STD_LOGIC_VECTOR(16 DOWNTO 0) := (OTHERS => '0'); -- the address at which next pixel should be read for display
    SIGNAL pix_read_addr0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0'); -- the RAM0 address at which next pixel should be read for display
    SIGNAL pix_read_addr1 : STD_LOGIC_VECTOR(13 DOWNTO 0) := (OTHERS => '0'); -- the RAM1 address at which next pixel should be read for display
    SIGNAL pix_read_MSBdly : STD_LOGIC_VECTOR(1 DOWNTO 0); -- MSB of RAM read address to folow pipeline
    SIGNAL next_pixel0 : STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0);
    SIGNAL next_pixel1 : STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0);
    SIGNAL next_pixel : STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0);
    FUNCTION fill(vect_in : STD_LOGIC_VECTOR; outsize : INTEGER) RETURN STD_LOGIC_VECTOR IS
        VARIABLE idx : INTEGER;
        VARIABLE vect_out : STD_LOGIC_VECTOR(outsize - 1 DOWNTO 0);
    BEGIN
        idx := vect_in'left;
        FOR odx IN outsize - 1 DOWNTO 0 LOOP
            vect_out(odx) := vect_in(idx);
            IF idx > vect_in'right THEN
                idx := idx - 1;
            ELSE
                idx := vect_in'left;
            END IF;
        END LOOP;
        RETURN vect_out;
    END FUNCTION;

    SIGNAL i_palette_w : STD_LOGIC;
    SIGNAL i_palette_idx : STD_LOGIC_VECTOR(RAM_BPP - 1 DOWNTO 0);
    SIGNAL i_palette_val : STD_LOGIC_VECTOR(HARD_BPP - 1 DOWNTO 0);
BEGIN
    preRAMaddr_x <= "00000000" & pixel_x;
    preRAMaddr_y5 <= "0" & pixel_y & "00000000";
    preRAMaddr_y1 <= "000" & pixel_y & "000000";

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                RAM_addr <= (OTHERS => '1');
            ELSIF to_integer(unsigned(pixel_x)) > 319 THEN
                RAM_addr <= (OTHERS => '1');
            ELSIF to_integer(unsigned(pixel_y)) > 239 THEN
                RAM_addr <= (OTHERS => '1');
            ELSE
                RAM_addr <= STD_LOGIC_VECTOR(unsigned(preRAMaddr_x) + unsigned(preRAMaddr_y5) + unsigned(preRAMaddr_y1));
            END IF;
            delayed_wr <= data_write;
            IF READBACK /= 0 THEN
                delayed_rd <= data_read;
            ELSE
                delayed_rd <= '0';
            END IF;
            pixel_in_dly0 <= data_in;

            RAM_addr0 <= RAM_addr(15 DOWNTO 0);
            delayed_wr0 <= delayed_wr AND NOT RAM_addr(16);
            delayed_rd0 <= delayed_rd AND NOT RAM_addr(16);
            RAM_addr1 <= RAM_addr(13 DOWNTO 0);
            delayed_wr1 <= delayed_wr AND RAM_addr(16) AND NOT RAM_addr(15) AND NOT RAM_addr(14);
            delayed_rd1 <= delayed_rd AND RAM_addr(16) AND NOT RAM_addr(15) AND NOT RAM_addr(14);
            pixel_in_dly1 <= pixel_in_dly0;

            delayed_rdp0 <= delayed_rd0;
            delayed_rdp1 <= delayed_rd1;

        END IF;
    END PROCESS;
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                pix_read_addr <= (OTHERS => '0');
            ELSIF Vsync_state = state_sync THEN
                pix_read_addr <= (OTHERS => '0');
            ELSIF clk_prediv_en = '1' AND Vsync_state = state_display AND Hsync_state = state_display AND Hsync_cnt MOD 2 = 1 THEN
                pix_read_addr <= STD_LOGIC_VECTOR(unsigned(pix_read_addr) + 1);
            ELSIF clk_prediv_en = '1' AND Vsync_state = state_display AND Hsync_state = state_sync AND Hsync_cnt = 0 AND (Vsync_cnt MOD 2 = 0) THEN
                pix_read_addr <= STD_LOGIC_VECTOR(unsigned(pix_read_addr) - 320);
            END IF;
        END IF;
    END PROCESS;
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            -- if reset = '1' then
            --     pix_read_addr0 <= (others => '0');
            --     pix_read_addr1 <= (others => '0');
            -- else
            pix_read_addr0 <= pix_read_addr(15 DOWNTO 0);
            pix_read_addr1 <= pix_read_addr(13 DOWNTO 0);
            pix_read_MSBdly(0) <= pix_read_addr(16);
            pix_read_MSBdly(1) <= pix_read_MSBdly(0);
            -- end if;
        END IF;
    END PROCESS;
    -- This process performs data access (read and write) to the memory
    memory_management : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            next_pixel0 <= screen0(to_integer(unsigned(pix_read_addr0)));
            next_pixel1 <= screen1(to_integer(unsigned(pix_read_addr1)));

            data_out0 <= screen0(to_integer(unsigned(RAM_addr0)));
            data_out1 <= screen1(to_integer(unsigned(RAM_addr1)));
            IF delayed_wr0 = '1' THEN
                screen0(to_integer(unsigned(RAM_addr0))) <= pixel_in_dly1;
            END IF;
            IF delayed_wr1 = '1' THEN
                screen1(to_integer(unsigned(RAM_addr1))) <= pixel_in_dly1;
            END IF;
        END IF;
    END PROCESS;

    -- data output process
    dout_mgr : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                data_out <= (OTHERS => '0');
                data_rout <= '0';
            ELSIF delayed_rdp0 = '1' THEN
                data_out <= data_out0;
                data_rout <= '1';
            ELSIF delayed_rdp1 = '1' THEN
                data_out <= data_out1;
                data_rout <= '1';
            ELSE
                data_out <= (OTHERS => '0');
                data_rout <= '0';
            END IF;
        END IF;
    END PROCESS;

    ---------------------------------------------------------------------

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                clk_prediv_cnt <= clk_prediv;
                clk_prediv_en <= '0';
            ELSIF clk_prediv_cnt = 0 THEN
                clk_prediv_cnt <= clk_prediv;
                clk_prediv_en <= '1';
            ELSE
                clk_prediv_cnt <= clk_prediv_cnt - 1;
                clk_prediv_en <= '0';
            END IF;
        END IF;
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                Hsync_state <= state_front_porch;
                Hsync_cnt <= H_frontporch - 1;
            ELSIF clk_prediv_en = '1' THEN
                CASE Hsync_state IS
                    WHEN state_back_porch =>
                        IF Hsync_cnt = H_backporch THEN
                            Hsync_cnt <= 0;
                            Hsync_state <= state_display;
                        ELSE
                            Hsync_cnt <= Hsync_cnt + 1;
                        END IF;
                    WHEN state_sync =>
                        IF Hsync_cnt = H_syncpulse THEN
                            Hsync_cnt <= 0;
                            Hsync_state <= state_back_porch;
                        ELSE
                            Hsync_cnt <= Hsync_cnt + 1;
                        END IF;
                    WHEN state_front_porch =>
                        IF Hsync_cnt = H_frontporch THEN
                            Hsync_cnt <= 0;
                            Hsync_state <= state_sync;
                        ELSE
                            Hsync_cnt <= Hsync_cnt + 1;
                        END IF;
                    WHEN state_display =>
                        IF Hsync_cnt = H_pixsize THEN
                            Hsync_cnt <= 0;
                            Hsync_state <= state_front_porch;
                        ELSE
                            Hsync_cnt <= Hsync_cnt + 1;
                        END IF;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                new_line_en <= False;
            ELSIF clk_prediv = 0 AND Hsync_state = state_sync AND Hsync_cnt = H_syncpulse - 1 THEN
                new_line_en <= True;
            ELSIF clk_prediv /= 0 AND clk_prediv_cnt = 0 AND Hsync_state = state_sync AND Hsync_cnt = H_syncpulse THEN
                new_line_en <= True;
            ELSE
                new_line_en <= False;
            END IF;
        END IF;
    END PROCESS;
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                VGA_hs_dly <= (OTHERS => '1');
                VGA_hs <= '1';
            ELSIF Hsync_state = state_sync THEN
                VGA_hs_dly(0) <= H_sync_pos;
                VGA_hs_dly(2 DOWNTO 1) <= VGA_hs_dly(1 DOWNTO 0);
                VGA_hs <= VGA_hs_dly(2);
            ELSE
                VGA_hs_dly(0) <= NOT H_sync_pos;
                VGA_hs_dly(2 DOWNTO 1) <= VGA_hs_dly(1 DOWNTO 0);
                VGA_hs <= VGA_hs_dly(2);
            END IF;
        END IF;
    END PROCESS;
    end_of_frame <= local_frame_end;
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                local_frame_end <= '1';
            ELSIF Vsync_state = state_display AND Vsync_cnt = V_pixsize AND Hsync_state = state_front_porch THEN
                local_frame_end <= '1';
            ELSE
                local_frame_end <= '0';
            END IF;
        END IF;
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                Vsync_state <= state_front_porch;
                Vsync_cnt <= V_frontporch - 1;
            ELSIF new_line_en THEN
                CASE Vsync_state IS
                    WHEN state_back_porch =>
                        IF Vsync_cnt = V_backporch THEN
                            Vsync_cnt <= 0;
                            Vsync_state <= state_display;
                        ELSE
                            Vsync_cnt <= Vsync_cnt + 1;
                        END IF;
                    WHEN state_sync =>
                        IF Vsync_cnt = V_syncpulse THEN
                            Vsync_cnt <= 0;
                            Vsync_state <= state_back_porch;
                        ELSE
                            Vsync_cnt <= Vsync_cnt + 1;
                        END IF;
                    WHEN state_front_porch =>
                        IF Vsync_cnt = V_frontporch THEN
                            Vsync_cnt <= 0;
                            Vsync_state <= state_sync;
                        ELSE
                            Vsync_cnt <= Vsync_cnt + 1;
                        END IF;
                    WHEN state_display =>
                        IF Vsync_cnt = V_pixsize THEN
                            Vsync_cnt <= 0;
                            Vsync_state <= state_front_porch;
                        ELSE
                            Vsync_cnt <= Vsync_cnt + 1;
                        END IF;
                END CASE;
            END IF;
        END IF;
    END PROCESS;
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                VGA_vs_dly <= (OTHERS => '1');
                VGA_vs <= '1';
            ELSIF Vsync_state = state_sync THEN
                VGA_vs_dly(0) <= V_sync_pos;
                VGA_vs_dly(2 DOWNTO 1) <= VGA_vs_dly(1 DOWNTO 0);
                VGA_vs <= VGA_vs_dly(2);
            ELSE
                VGA_vs_dly(0) <= NOT V_sync_pos;
                VGA_vs_dly(2 DOWNTO 1) <= VGA_vs_dly(1 DOWNTO 0);
                VGA_vs <= VGA_vs_dly(2);
            END IF;
        END IF;
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                next_pixel <= (OTHERS => '0');
            ELSIF pix_read_MSBdly(1) = '0' THEN
                next_pixel <= next_pixel0;
            ELSE
                next_pixel <= next_pixel1;
            END IF;
            IF Vsync_state = state_display AND Hsync_state = state_display THEN
                pixout(0) <= '1';
            ELSE
                pixout(0) <= '0';
            END IF;
            pixout(2 DOWNTO 1) <= pixout(1 DOWNTO 0);

        END IF;
    END PROCESS;
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                VGA_color <= (OTHERS => '0');
            ELSIF pixout(2) = '0' THEN
                VGA_color <= (OTHERS => '0');
            ELSIF INDEXED /= 0 THEN
                VGA_color <= palette(to_integer(unsigned(next_pixel)));
            ELSE

                CASE RAM_BPP IS
                    WHEN 1 =>
                        VGA_color <= (OTHERS => next_pixel(0));
                    WHEN 2 =>
                        VGA_color(HARD_BPP - 1 DOWNTO HARD_BPP - HARD_BPP/3) <= (OTHERS => (next_pixel(0) AND next_pixel(1)));
                        VGA_color(HARD_BPP - HARD_BPP/3 - 1 DOWNTO HARD_BPP/3) <= (OTHERS => (next_pixel(1) AND NOT next_pixel(0)));
                        VGA_color(HARD_BPP/3 - 1 DOWNTO 0) <= (OTHERS => (next_pixel(0) AND NOT next_pixel(1)));
                    WHEN 3 =>
                        VGA_color(HARD_BPP - 1 DOWNTO HARD_BPP - HARD_BPP/3) <= (OTHERS => next_pixel(2));
                        VGA_color(HARD_BPP - HARD_BPP/3 - 1 DOWNTO HARD_BPP/3) <= (OTHERS => next_pixel(1));
                        VGA_color(HARD_BPP/3 - 1 DOWNTO 0) <= (OTHERS => next_pixel(0));
                    WHEN 4 =>
                        IF next_pixel = "1000" THEN
                            VGA_color(HARD_BPP - 1) <= '0';
                            VGA_color(HARD_BPP - HARD_BPP/3 - 1) <= '0';
                            VGA_color(HARD_BPP/3 - 1) <= '0';
                            VGA_color(HARD_BPP - 2) <= '1';
                            VGA_color(HARD_BPP - HARD_BPP/3 - 2) <= '1';
                            VGA_color(HARD_BPP/3 - 2) <= '1';
                            VGA_color(HARD_BPP - 3 DOWNTO HARD_BPP - HARD_BPP/3) <= (OTHERS => '0');
                            VGA_color(HARD_BPP - HARD_BPP/3 - 3 DOWNTO HARD_BPP/3) <= (OTHERS => '0');
                            VGA_color(HARD_BPP/3 - 3 DOWNTO 0) <= (OTHERS => '0');
                        ELSE
                            VGA_color(HARD_BPP - 1) <= next_pixel(2);
                            VGA_color(HARD_BPP - HARD_BPP/3 - 1) <= next_pixel(1);
                            VGA_color(HARD_BPP/3 - 1) <= next_pixel(0);
                            VGA_color(HARD_BPP - 2 DOWNTO HARD_BPP - HARD_BPP/3) <= (OTHERS => (next_pixel(2) AND next_pixel(3)));
                            VGA_color(HARD_BPP - HARD_BPP/3 - 2 DOWNTO HARD_BPP/3) <= (OTHERS => (next_pixel(1) AND next_pixel(3)));
                            VGA_color(HARD_BPP/3 - 2 DOWNTO 0) <= (OTHERS => (next_pixel(0) AND next_pixel(3)));
                        END IF;
                    WHEN 6 =>
                        VGA_color(HARD_BPP - 1 DOWNTO HARD_BPP - HARD_BPP/3) <= fill(next_pixel(5 DOWNTO 4), HARD_BPP /3);
                        VGA_color(HARD_BPP - HARD_BPP/3 - 1 DOWNTO HARD_BPP/3) <= fill(next_pixel(3 DOWNTO 2), (HARD_BPP + 2)/3);
                        VGA_color(HARD_BPP/3 - 1 DOWNTO 0) <= fill(next_pixel(1 DOWNTO 0), HARD_BPP /3);
                    WHEN 7 =>
                        VGA_color(HARD_BPP - 1 DOWNTO HARD_BPP - HARD_BPP/3) <= fill(next_pixel(7 DOWNTO 5), HARD_BPP /3);
                        VGA_color(HARD_BPP - HARD_BPP/3 - 1 DOWNTO HARD_BPP/3) <= fill(next_pixel(4 DOWNTO 2), (HARD_BPP + 2)/3);
                        VGA_color(HARD_BPP/3 - 1 DOWNTO 0) <= fill(next_pixel(1 DOWNTO 0), HARD_BPP /3);
                    WHEN 9 =>
                        VGA_color(HARD_BPP - 1 DOWNTO HARD_BPP - HARD_BPP/3) <= fill(next_pixel(8 DOWNTO 6), HARD_BPP /3);
                        VGA_color(HARD_BPP - HARD_BPP/3 - 1 DOWNTO HARD_BPP/3) <= fill(next_pixel(5 DOWNTO 3), (HARD_BPP + 2)/3);
                        VGA_color(HARD_BPP/3 - 1 DOWNTO 0) <= fill(next_pixel(2 DOWNTO 0), HARD_BPP /3);
                    WHEN 10 =>
                        VGA_color(HARD_BPP - 1 DOWNTO HARD_BPP - HARD_BPP/3) <= fill(next_pixel(9 DOWNTO 7), HARD_BPP /3);
                        VGA_color(HARD_BPP - HARD_BPP/3 - 1 DOWNTO HARD_BPP/3) <= fill(next_pixel(6 DOWNTO 3), (HARD_BPP + 2)/3);
                        VGA_color(HARD_BPP/3 - 1 DOWNTO 0) <= fill(next_pixel(2 DOWNTO 0), HARD_BPP /3);
                    WHEN 12 =>
                        VGA_color(HARD_BPP - 1 DOWNTO HARD_BPP - HARD_BPP/3) <= fill(next_pixel(11 DOWNTO 8), HARD_BPP /3);
                        VGA_color(HARD_BPP - HARD_BPP/3 - 1 DOWNTO HARD_BPP/3) <= fill(next_pixel(7 DOWNTO 4), (HARD_BPP + 2)/3);
                        VGA_color(HARD_BPP/3 - 1 DOWNTO 0) <= fill(next_pixel(3 DOWNTO 0), HARD_BPP /3);
                    WHEN OTHERS =>
                        VGA_color <= (OTHERS => '0');
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF INDEXED /= 0 THEN
                i_palette_w <= palette_w;
                i_palette_idx <= palette_idx;
                i_palette_val <= palette_val;
                IF i_palette_w = '1' THEN
                    palette(to_integer(unsigned(i_palette_idx))) <= i_palette_val;
                END IF;
            END IF;
        END IF;
    END PROCESS;
    ----------------------

END Behavioral;