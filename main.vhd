library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity dungeon_ex is
        -- Adding generic number of lives (attempts)
           generic 
                (
                    ATTEMPTS : integer := 1; -- log2(total number of lives) rounded up
                    LEVELS : integer := 1; -- log2(total number of levels) rounded up
                    scale : integer := 1 -- log2(total number of levels) rounded up
                ); 
           
    Port ( 
        -- FPGA components
           clk : in  STD_LOGIC;
           btnU, btnD, btnL, btnR,btnC: in std_logic;
           led : out  STD_LOGIC_VECTOR (15 downto 0);
           seg : out  STD_LOGIC_VECTOR (6 downto 0);
           dp : out STD_LOGIC;
           an : out  STD_LOGIC_VECTOR (3 downto 0);
           sw : in  STD_LOGIC_VECTOR (15 downto 0);
       -- VGA ports
           vgaRed : out  STD_LOGIC_VECTOR(3 DOWNTO 0);
           vgaGreen : out  STD_LOGIC_VECTOR(3 DOWNTO 0);
           vgaBlue : out  STD_LOGIC_VECTOR(3 DOWNTO 0);
           HSync : out  STD_LOGIC;
           VSync : out  STD_LOGIC);
end dungeon_ex;
 
architecture Behavioral of dungeon_ex is

-- COMPONENT DECLARATIONS    
component vga_sync 
    Port ( 
           clk : in  STD_LOGIC;
           rst: in STD_LOGIC;
           -- to VGA ports
           HSync : out  STD_LOGIC;
           VSync : out  STD_LOGIC;
           -- to Graphics Engine
           current_x: out STD_LOGIC_VECTOR(9 downto 0);
           current_y: out STD_LOGIC_VECTOR(9 downto 0);
           onDisplay: out STD_LOGIC;
           endOfFrame: out STD_LOGIC;
           clk_vga: out STD_LOGIC
           );
end component;

component timer is
    Port ( 
           start: in std_logic; -- from dungeon_ex    
           clk : in  STD_LOGIC;
        --Output
           digit_0: out std_logic_vector(3 downto 0);
           digit_1: out std_logic_vector(3 downto 0);
           digit_2: out std_logic_vector(3 downto 0);
           timeP: out std_logic_vector(6 downto 0);
           sec_clock: out std_logic                    
           );
end component;

component Disp_Timer is
Port ( 
    count : in std_logic_vector(11 downto 0); -- set to bcd_out from bin2bcd
    seg : out STD_LOGIC_VECTOR (6 downto 0); 
    dp : out STD_LOGIC;
    an : out STD_LOGIC_VECTOR (3 downto 0);
    clk : in STD_LOGIC;
    rst : in STD_LOGIC -- Start flag from dungeon_ex (reset timer)
); 
end component;
-- SIGNAL DEFINITIONS
    -- Initials
        signal x, x_end, y, y_end: std_logic_vector(5 downto 0);
        signal chooseMap: std_logic_vector(2 downto 0);
        signal doorLock: std_logic_vector(5 downto 0);
        signal ScoreLock: std_logic_vector(19 downto 0);
        signal keyLock: std_logic;
        signal deadKey: std_logic;        
    -- FLAGS (For any events)
        -- Completion
            signal finished: std_logic := '0'; -- In case player reaches end of map, set to 1 then 0 on next clk;
        -- MISC
            signal player_reset: std_logic; -- In case player dies, or resets with btnC
        -- Start timer for score
            signal start: std_logic; --1 when player starts to move, 0 when beginning of level

		-- SELECTION (For multiplexors)
        signal ChooseLevel: std_logic_vector(LEVELS downto 0) := (others => '0'); -- Choose initial values, start at level 1 => '0'

	-- PLAYER
        -- Game dynamics
        signal player_x: STD_LOGIC_VECTOR(5 downto 0);
        signal player_y: STD_LOGIC_VECTOR(5 downto 0);
        signal playerScore: std_logic_vector(15 downto 0);
        signal playerLife: std_logic_vector(ATTEMPTS downto 0);
        signal playerTimer: std_logic_vector(6 downto 0);

    -- COLOR CONSTANTS
        constant RED: STD_LOGIC_VECTOR(11 downto 0) := "111100000000";
		constant GREEN: STD_LOGIC_VECTOR(11 downto 0) := "000011110000";
		constant KEY_COLOR: STD_LOGIC_VECTOR(11 downto 0) := "110000000000";
		constant DOOR_COLOR: STD_LOGIC_VECTOR(11 downto 0) := "111010001000";
		constant BLUE: STD_LOGIC_VECTOR(11 downto 0) := "000000001111";
		constant BLACK: STD_LOGIC_VECTOR(11 downto 0) := "000000000000";
		constant WHITE: STD_LOGIC_VECTOR(11 downto 0) := "111111111111";
		constant COINS: STD_LOGIC_VECTOR(11 downto 0) := "111111000000";

		
-- ARRAYS
	--numbers
type num_0 is array (0 to 4) of std_logic_vector(0 to 4);
constant num0: num_0 := 
                    (
                        "11111",
						"10001",
						"10001",
						"10001",
						"11111"
					);

type num_1 is array (0 to 4) of std_logic_vector(0 to 4);
constant num1: num_1 := 
                    (
                        "01100",
						"10100",
						"00100",
						"00100",
						"11111"
					);
type num_2 is array (0 to 4) of std_logic_vector(0 to 4);
constant num2: num_2 := 
                    (
                        "01110",
						"10001",
						"00010",
						"01000",
						"11111"
					);
type num_3 is array (0 to 4) of std_logic_vector(0 to 4);
constant num3: num_3 := 
                    (
                        "11111",
						"00001",
						"00111",
						"00001",
						"11111"
					);
type num_4 is array (0 to 4) of std_logic_vector(0 to 4);
constant num4: num_4 := 
                    (
                        "00110",
						"01010",
						"11111",
						"00010",
						"00010"
					);
type num_5 is array (0 to 4) of std_logic_vector(0 to 4);
constant num5: num_5 := 
                    (
                        "11111",
						"10000",
						"11111",
						"00001",
						"11111"
					);
type num_6 is array (0 to 4) of std_logic_vector(0 to 4);
constant num6: num_6 := 
                    (
                        "11111",
						"10000",
						"11111",
						"10001",
						"11111"
					);
type num_7 is array (0 to 4) of std_logic_vector(0 to 4);
constant num7: num_7 := 
                    (
                        "11111",
						"00001",
						"00001",
						"00001",
						"00001"
					);
type num_8 is array (0 to 4) of std_logic_vector(0 to 4);
constant num8: num_8 := 
                    (
                        "11111",
						"10001",
						"11111",
						"10001",
						"11111"
					);
type num_9 is array (0 to 4) of std_logic_vector(0 to 4);
constant num9: num_9 := 
                    (
						"11111",
						"10001",
						"11111",
						"00001",
						"11111"
					);


	--door
            type doorArray is array (0 to 10) of std_logic_vector(0 to 9);
                constant door: doorArray := 
                    (
                        "0000000000",
                        "0000000000",
                        "1111111111",
                        "1000000001",
                        "1000000001",
                        "1000011001",
                        "1000011001",
                        "1000000001",
                        "1111111111",
                        "0000000000",
                        "0000000000"
                    );

					
	
	--dungeon wall level 1
	
type wallArray is array (0 to 45) of std_logic_vector(0 to 45);
constant dunWall: wallArray := 
(
"0000000000000000000000000000000000000000000000",
"0000000000000000000000000000000000000000000000",
"0011111100110011111111111111111111111111111100",
"0011111100110011111111111111111111111111111100",
"0011111100110011000000000011000000000000001100",
"0011111100110011000000000011000000000000001100",
"0011111100111111111111110011000000000011111100",
"0011111100111111111111110011000000000011111100",
"0011000000000000000000000011000000000011000000",
"0011000000000000000000000011000000000011000000",
"0011111111111111111111111111000000111111001100",
"0011111111111111111111111111000000111111001100",
"0000000000000000000000111111000000110000001100",
"0000000000000000000000111111000000110000001100",
"0011111111110000000000111111000000110011111100",
"0011111111110000000000111111000000110011111100",
"0011001100110000000000000000000000110000001100",
"0011001100110000000000000000000000110000001100",
"0011001100110000000000000000000000111111111100",
"0011001100110000000000000000000000111111111100",
"0011001100000000000000000000000000000000001100",
"0011001100000000000000000000000000000000001100",
"0011001111111111000000000000000000000000001100",
"0011001111111111000000000000000000000000001100",
"0000000000000011000000000000000000000000001100",
"0000000000000011000000000000000000000000001100",
"0011111111111111000000000000000000110000001100",
"0011111111111111000000000000000000110000001100",
"0011000000000011000000000000000000110000001100",
"0011000000000011000000000000000000110000001100",
"0011000000111111000000000000000000110000001100",
"0011000000111111000000000000000000110000001100",
"0011000000111111000000000000000000110000001100",
"0011000000111111000000000000000000110000001100",
"0011000000111111001111111111111111110000001100",
"0011000000111111001111111111111111110000001100",
"0011000000111111001100000000000000000000001100",
"0011000000111111001100000000000000000000001100",
"0011111111111111111111111111111111111111111100",
"0011111111111111111111111111111111111111111100",
"0011000000000000000000000000000000000000000000",
"0011000000000000000000000000000000000000000000",
"0011111111111111111111111111111111111111111100",
"0011111111111111111111111111111111111111111100",
"0000000000000000000000000000000000000000000000",
"0000000000000000000000000000000000000000000000"    
);

	--dungeon level 2
	
type wallArray2 is array (0 to 45) of std_logic_vector(0 to 45);
constant dunWall2: wallArray2 := 
(
"0000000000000000000000000000000000000000000000",
"0000000000000000000000000000000000000000000000",
"0011111111111111111111111111111111111111001100",
"0011111111111111111111111111111111111111001100",
"0000000000000000000000110000000000000011001100",
"0000000000000000000000110000000000000011001100",
"0011111111111111111111110011111111110011001100",
"0011111111111111111111110011111111110011001100",
"0011111111111111111100000011111111110011001100",
"0011111111111111111100000011111111110011001100",
"0011111111111111111100110011111111110011001100",
"0011111111111111111100110011111111110011001100",
"0011111111111111111100110011111111110011001100",
"0011111111111111111100110011111111110011001100",
"0011111111111111111111110011111111110011001100",
"0011111111111111111111110011111111110011001100",
"0000000000000000001100000011000000000011001100",
"0000000000000000001100000011000000000011001100",
"0011111111110011111111111111111111110011111100",
"0011111111110011111111111111111111110011111100",
"0011000000110011111111111111111111110000001100",
"0011000000110011111111111111111111110000001100",
"0011111100111111111111111111111111110011111100",
"0011111100111111111111111111111111110011111100",
"0000001100110011111111111111111111110011000000",
"0000001100110011111111111111111111110011000000",
"0011111100110011111111111111111111110011001100",
"0011111100110011111111111111111111110011001100",
"0000000000110011111111111111111111110011001100",
"0000000000110011111111111111111111110011001100",
"0011111100111111111111111111111111110011111100",
"0011111100111111111111111111111111110011111100",
"0011001100000011111111111111111111110000001100",
"0011001100000011111111111111111111110000001100",
"0011001111111111111111111111111111110011001100",
"0011001111111111111111111111111111110011001100",
"0011000000000000000000000000000000110011001100",
"0011000000000000000000000000000000110011001100",
"0011001111111111111111111111111111111111001100",
"0011001111111111111111111111111111111111001100",
"0011000000000000000000000000000000000000001100",
"0011000000000000000000000000000000000000001100",
"0011111111111111111111111111111111111111111100",
"0011111111111111111111111111111111111111111100",
"0000000000000000000000000000000000000000000000",
"0000000000000000000000000000000000000000000000"
);

--other stuff
signal rst: STD_LOGIC;
signal colorOut: STD_LOGIC_VECTOR(11 downto 0); -- One signal to concatanate the

-- Sync related
signal clk_vga: STD_LOGIC;
signal current_x: STD_LOGIC_VECTOR(9 downto 0);
signal current_y: STD_LOGIC_VECTOR(9 downto 0);
signal onDisplay: STD_LOGIC;
signal endOfFrame: STD_LOGIC;
signal counter_move: STD_LOGIC_VECTOR(23 downto 0);
signal p_countBCD: STD_LOGIC_VECTOR(11 downto 0);

-- Pixel Size
constant wall_pixel_x: STD_LOGIC_VECTOR(3 downto 0) := "1010"; -- 10 =  480/46
constant wall_pixel_y: STD_LOGIC_VECTOR(3 downto 0) := "1010"; -- 10 =  480/46
constant player_pixel_x: STD_LOGIC_VECTOR(3 downto 0) := "1010"; -- 10 =  480/240
constant player_pixel_y: STD_LOGIC_VECTOR(3 downto 0) := "1010"; -- 10 =  480/240

-- Timer related
signal dig0, dig1, dig2: std_logic_vector(3 downto 0);


type ScoreDisp is array (0 to 4) of std_logic_vector(0 to 17);
constant screen0: ScoreDisp :=
(
"111011011101110111",
"100010010101010100",
"111010010101110110",
"001010010101100100",
"111011011101010111"
);

type TimerDisp is array (0 to 4) of std_logic_vector(0 to 17);
constant screen1: TimerDisp :=
(
"111011101000101110",
"010001001101101000",
"010001001010101100",
"010001001000101000",
"010011101000101110"
);

type LifeDisp is array (0 to 4) of std_logic_vector(0 to 17);
constant screen2: LifeDisp :=
(
"010001110111011100",
"010000100100010000",
"010000100111011100",
"010000100100010000",
"011101110100011101"
);            

signal playerT: std_logic_vector(6 downto 0);
signal secClock: std_logic;

--BEGIN ARCHITECTURE
begin
TIM:Timer port map(start,clk,dig0, dig1, dig2, playerT, secClock);
p_countBCD <= dig2 & dig1 & dig0;
BCD_DISP:Disp_Timer port map(p_countBCD,seg,dp,an,clk,start);
player_reset <= btnC ; -- or timeUP;

-- Process to choose initial values
selInitial: process(ChooseLevel)
    begin
           case ChooseLevel is
           when "00" => x <= "101011"; y <= "101011"; x_end <= "001011"; y_end <= "000010"; chooseMap <= "000"; -- Level 1 (10, 2)
           when "01" => x <= "000010"; y <= "000010"; x_end <= "000110"; y_end <= "100111"; chooseMap <= "111";-- Level 2 (10,38)
           when others => x <= "101011"; y <= "101011"; x_end <= "001011"; y_end <= "000010"; chooseMap <= "000";
           end case;
   end process;           
           

--sync vga code
SYNC: vga_sync port map(
        clk => clk,
        rst => rst,
        -- to VGA ports
        HSync => HSync,
        VSync => VSync,
        -- to Graphics Engine
        current_x => current_x,
        current_y => current_y,
        onDisplay => onDisplay,
		endOfFrame => endOfFrame,
        clk_vga   => clk_vga
);
vgaRed <= colorOut(11 downto 8);
vgaGreen <= colorOut(7 downto 4);
vgaBlue <= colorOut(3 downto 0);
led <= sw ;
doorLock <=  sw(5 downto 0);
rst <= sw(15);


-- display process 
DISPLAY1:process(current_x,current_y,player_x,player_y, chooseMap, doorLock, playerTimer)
begin

    if(onDisplay = '1') then
        if (chooseMap = "111") then
            if (to_integer(unsigned(current_y)) < 460 and to_integer(unsigned(current_x)) < 460) then
                    if (dunWall2(to_integer(unsigned(current_y)/unsigned(wall_pixel_y)))(to_integer(unsigned(current_x)/unsigned(wall_pixel_x))) = '0' ) then
                        colorOut<=BLACK;
                        elsif (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = player_x and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = player_y) then
                                      colorOut<=RED;
                        elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 21 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 6) or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 21 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 7 and doorLock(0) = '0') or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 21 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 14) or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 21 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 15 and doorLock(1) = '0') or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 13 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 30) or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 13 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 31 and doorLock(2) = '0') or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 13 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 34) or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 13 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 35 and doorLock(3) = '0') or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 13 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 22) or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 13 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 23 and doorLock(4) = '0') or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 34 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 36) or
                               (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 35 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 36 and doorLock(5) = '0')
                               )then
                                    colorOut<=DOOR_COLOR;
                                elsif ( (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 39 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 35 and deadKey = '0' ) or
                                    (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 2 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 26 and keyLock = '0' ) or
                                    (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 8 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 38 and keyLock = '0') or
                                     (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 8 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39  and keyLock = '0' ))then
                                    colorOut<=KEY_COLOR;
                                elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 5  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 2 and ScoreLock(0) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 10  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 2 and ScoreLock(1) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 15  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 2 and ScoreLock(2) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 22  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 4 and ScoreLock(3) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 43  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 4 and ScoreLock(4) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 7  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 7 and ScoreLock(5) = '0') or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 17  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 7 and ScoreLock(6) = '0') or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 27  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 7 and ScoreLock(7) = '0') or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 30  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 8 and ScoreLock(8) = '0') or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 27 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 9 and ScoreLock(9) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 32 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 10 and ScoreLock(10) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 7 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 28 and ScoreLock(11) = '0') or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 17  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 29 and ScoreLock(12) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 25  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 30 and ScoreLock(13) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 27  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 32 and ScoreLock(14) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 3  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 43 and ScoreLock(15) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 7  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 43 and ScoreLock(16) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) =  20  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 42 and ScoreLock(17) = '0') or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 33 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 42 and ScoreLock(18) = '0' ) or
                                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 43 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 28 and ScoreLock(19) = '0' ))then
                                        colorOut<=COINS;
                                elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 2 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 2) or
                                       (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 2 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 3))then
                                    colorOut<=BLUE;
                                elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 6 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 38) or
                                       (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 6 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39))then
                                    colorOut<=GREEN;
                    elsif (dunWall2(to_integer(unsigned(current_y)/unsigned(wall_pixel_y)))(to_integer(unsigned(current_x)/unsigned(wall_pixel_x))) = '1' ) then
                        colorOut<=WHITE; 
                    else
                        colorOut<=BLACK;
                    end if;
            elsif (to_integer(unsigned(current_x)) > 465 and to_integer(unsigned(current_x)) < 501 and to_integer(unsigned(current_y)) > 19 and to_integer(unsigned(current_y)) < 70)  then
                                    if (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) < 501)  then
                                        if (screen0((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-233))) = '1' ) then
                                            colorOut<=WHITE; 
                                        else
                                            colorOut<=BLACK;
                                        end if;                 
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) < 501)  then
                                        if (screen1((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-233))) = '1' ) then
                                            colorOut<=WHITE; 
                                        else
                                            colorOut<=BLACK;
                                        end if;  
                                    elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) < 501)  then
                                        if (screen2((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-233))) = '1' ) then
                                            colorOut<=WHITE; 
                                        else
                                            colorOut<=BLACK;
                                        end if;                                             
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                elsif (to_integer(unsigned(current_x)) > 511 and to_integer(unsigned(current_x)) < 562 and to_integer(unsigned(current_y)) > 19 and to_integer(unsigned(current_y)) < 70)  then
                                -- 100th place
                                        --display 0 on score
                                         if (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) < 522)  then
                                           if (num0((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-256))) = '1' ) then
                                                colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                            end if;
                                        -- display 0 on time                 
                                        elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) < 522
                                                and (to_integer(unsigned(playerTimer)) - (unsigned(playerTimer) mod 100))/100 = 0)  then
                                           if (num0((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-256))) = '1' ) then
                                                colorOut<=WHITE; 
                                          else
                                             colorOut<=BLACK;
                                           end if; 
                                        -- display 1 on time
                                        elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) < 522
                                                and (to_integer(unsigned(playerTimer)) - (unsigned(playerTimer) mod 100))/100 = 1)  then
                                            if (num1((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-256))) = '1' ) then
                                                colorOut<=WHITE; 
                                            else
                                                colorOut<=BLACK;
                                            end if;
                                        --display 0 on life 
                                        elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) < 522)  then
                                            if (num0((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-256))) = '1' ) then
                                                colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if;          
                                 -- 10th place
                                        --display 0 on score
                                           elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 0)  then
                                           if (num0((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if;      
                                          --display 1 on score
                                           elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                                                   and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 1)  then
                                           if (num1((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if;  
                                           --display 2 on score
                                           elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                                                   and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 2)  then
                                           if (num2((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 3 on score
                                           elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                                                   and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 3)  then
                                           if (num3((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 4 on score
                                           elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                                                   and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 4)  then
                                           if (num4((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 0 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 0)  then
                                           if (num0((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 1 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 1)  then
                                           if (num1((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 2 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 2)  then
                                           if (num2((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 3 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 3)  then
                                           if (num3((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 4 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 4)  then
                                           if (num4((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 5 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 5)  then
                                           if (num5((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 6 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 6)  then
                                           if (num6((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 7 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 7)  then
                                           if (num7((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 8 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 8)  then
                                           if (num8((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 9 on time
                                           elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                                    and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 9)  then
                                           if (num9((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                               colorOut<=WHITE; 
                                           else
                                               colorOut<=BLACK;
                                           end if; 
                                           --display 0 on life 
                                           elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542)  then
                                              if (num0((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                                                   colorOut<=WHITE; 
                                               else
                                                  colorOut<=BLACK;
                                               end if;       
                           --1st place  
                                      --display 0 on score
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                             and to_integer(unsigned(playerScore) mod 10) = 0)  then
                                      if (num0((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if;
                                      --display 1 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 1)  then
                                      if (num1((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if;
                                      --display 2 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 2)  then
                                      if (num2((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if; 
                                      --display 3 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 3)  then
                                      if (num3((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if; 
                                      --display 4 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 4)  then
                                      if (num4((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if; 
                                      --display 5 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 5)  then
                                      if (num5((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if; 
                                      --display 6 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 6)  then
                                      if (num6((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if; 
                                      --display 7 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 7)  then
                                      if (num7((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if; 
                                      --display 8 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 8)  then
                                      if (num8((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if; 
                                      --display 9 on score 
                                      elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                                          and to_integer(unsigned(playerScore) mod 10) = 9)  then
                                      if (num9((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                          colorOut<=WHITE; 
                                      else
                                          colorOut<=BLACK;
                                      end if;   
                                     -- display 0 on time              
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 0)  then
                                    if (num0((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if; 
                                    --display 1 on time
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 1)  then
                                    if (num1((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                    --display 2 on time
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 2)  then
                                    if (num2((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                    --display 3 on playerTimer
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 3)  then
                                    if (num3((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                    --display 4 on time
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 4)  then
                                    if (num4((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                    --display 5 on time
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 5)  then
                                    if (num5((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                    --display 6 on time
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 6)  then
                                    if (num6((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                    --display 7 on time
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 7)  then
                                    if (num7((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                    --display 8 on time
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 8)  then
                                    if (num8((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                    --display 9 on time
                                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and to_integer(unsigned(playerTimer) mod 10) = 9)  then
                                    if (num9((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                        colorOut<=WHITE; 
                                    else
                                        colorOut<=BLACK;
                                    end if;
                                         --display 0 on life 
                                     elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and playerLife = "00")  then
                                         if (num0((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                             colorOut<=WHITE; 
                                         else
                                             colorOut<=BLACK;
                                         end if;
                                         --display 1 on life
                                      elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                             and playerLife = "01")  then
                                             if (num1((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                                 colorOut<=WHITE; 
                                             else
                                                 colorOut<=BLACK;
                                             end if; 
                                         --display 2 on life                                                            
                                     elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and playerLife = "10")  then
                                                 if (num2((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                                     colorOut<=WHITE; 
                                                 else
                                                     colorOut<=BLACK;
                                                 end if;
                                         --display 3 on life
                                     elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                                            and playerLife = "11")  then
                                                     if (num3((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                                         colorOut<=WHITE; 
                                                     else
                                                         colorOut<=BLACK;
                                                     end if;
                                     else
                                         colorOut<=BLACK;
                                      end if;
                                else
                                    colorOut<=BLACK;
        
            end if; 
        else
            if (to_integer(unsigned(current_y)) < 460 and to_integer(unsigned(current_x)) < 460) then
                if (dunWall((to_integer(unsigned(current_y)/unsigned(wall_pixel_y)))/scale)((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)))/scale) = '0' ) then
                colorOut<=BLACK;
            elsif (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = player_x and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = player_y) then
              colorOut<=RED;
            elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 7 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 38) or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 7 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39 and doorLock(0) = '0') or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 16 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 38) or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 16 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39 and doorLock(1) = '0') or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 14 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 29) or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 15 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 29 and doorLock(2) = '0') or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 2 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 8) or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 3 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 8 and doorLock(4) = '0') or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 21 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 10) or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 21 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 11 and doorLock(3) = '0')
                   )then
                colorOut<=DOOR_COLOR;
            elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 3 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 15 and deadKey = '0') or
                    (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 6 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 6 and keyLock = '0') or 
                    (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 10 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 4 and keyLock = '0') or
                    (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 11 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 4 and keyLock = '0' ))then
                colorOut<=KEY_COLOR;
			elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 6 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 3 and ScoreLock(0) = '0' ) or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 12  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39 and ScoreLock(1) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 16  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 3 and ScoreLock(2) = '0' ) or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 20  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 3 and ScoreLock(3) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 26  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39 and ScoreLock(4) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 30  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 3 and ScoreLock(5) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 3  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 6 and ScoreLock(6) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 6  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 16 and ScoreLock(7) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 11  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 6 and ScoreLock(8) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 15  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 6 and ScoreLock(9) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 28  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39 and ScoreLock(10) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 27  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 7 and ScoreLock(11) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 42  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 7 and ScoreLock(12) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 43  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39 and ScoreLock(13) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 34  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 10 and ScoreLock(14) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 26  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 10 and ScoreLock(15) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 22  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 11 and ScoreLock(16) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 12  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 11 and ScoreLock(17) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 4  and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 39 and ScoreLock(18) = '0') or
                        (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 3 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 43  and ScoreLock(19) = '0' ))then
                    colorOut<=COINS;
            elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 43 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 43) or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 43 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 42))then
                colorOut<=BLUE;
            elsif ((to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 10 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 2) or
                   (to_integer(unsigned(current_x)/unsigned(wall_pixel_x)) = 11 and to_integer(unsigned(current_y)/unsigned(wall_pixel_y)) = 2))then
                colorOut<=GREEN;
            elsif (dunWall((to_integer(unsigned(current_y)/unsigned(wall_pixel_y)))/scale)(to_integer((unsigned(current_x)/unsigned(wall_pixel_x)))/scale) = '1' ) then
               colorOut<=WHITE; 
            else
               colorOut<=BLACK;
            end if;
            elsif (to_integer(unsigned(current_x)) > 465 and to_integer(unsigned(current_x)) < 501 and to_integer(unsigned(current_y)) > 19 and to_integer(unsigned(current_y)) < 70)  then
                if (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) < 501)  then
                    if (screen0((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-233))) = '1' ) then
                        colorOut<=WHITE; 
                    else
                        colorOut<=BLACK;
                    end if;                 
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) < 501)  then
                    if (screen1((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-233))) = '1' ) then
                        colorOut<=WHITE; 
                    else
                        colorOut<=BLACK;
                    end if;  
                elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) < 501)  then
                    if (screen2((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-233))) = '1' ) then
                        colorOut<=WHITE; 
                    else
                        colorOut<=BLACK;
                    end if;                                             
                else
                    colorOut<=BLACK;
                end if;
            elsif (to_integer(unsigned(current_x)) > 511 and to_integer(unsigned(current_x)) < 562 and to_integer(unsigned(current_y)) > 19 and to_integer(unsigned(current_y)) < 70)  then
            -- 100th place
                    --display 0 on score
                     if (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) < 522)  then
                       if (num0((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-256))) = '1' ) then
                            colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                        end if;
                    -- display 0 on time                 
                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) < 522
                            and (to_integer(unsigned(playerTimer)) - (unsigned(playerTimer) mod 100))/100 = 0)  then
                       if (num0((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-256))) = '1' ) then
                            colorOut<=WHITE; 
                      else
                         colorOut<=BLACK;
                       end if; 
                    -- display 1 on time
                    elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) < 522
                            and (to_integer(unsigned(playerTimer)) - (unsigned(playerTimer) mod 100))/100 = 1)  then
                        if (num1((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-256))) = '1' ) then
                            colorOut<=WHITE; 
                        else
                            colorOut<=BLACK;
                        end if;
                    --display 0 on life 
                    elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) < 522)  then
                        if (num0((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-256))) = '1' ) then
                            colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if;          
             -- 10th place
                    --display 0 on score
                       elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 0)  then
                       if (num0((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if;      
                      --display 1 on score
                       elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                               and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 1)  then
                       if (num1((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if;  
                       --display 2 on score
                       elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                               and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 2)  then
                       if (num2((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 3 on score
                       elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                               and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 3)  then
                       if (num3((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 4 on score
                       elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 531  and to_integer(unsigned(current_x)) < 542
                               and ((to_integer(unsigned(playerScore) - (unsigned(playerScore) mod 10))) mod 100)/10 = 4)  then
                       if (num4((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 0 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 0)  then
                       if (num0((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 1 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 1)  then
                       if (num1((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 2 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 2)  then
                       if (num2((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 3 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 3)  then
                       if (num3((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 4 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 4)  then
                       if (num4((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 5 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 5)  then
                       if (num5((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 6 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 6)  then
                       if (num6((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 7 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 7)  then
                       if (num7((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 8 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 8)  then
                       if (num8((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 9 on time
                       elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542
                                and ((to_integer(unsigned(playerTimer) - (unsigned(playerTimer) mod 10))) mod 100)/10 = 9)  then
                       if (num9((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                           colorOut<=WHITE; 
                       else
                           colorOut<=BLACK;
                       end if; 
                       --display 0 on life 
                       elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 531 and to_integer(unsigned(current_x)) < 542)  then
                          if (num0((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-266))) = '1' ) then
                               colorOut<=WHITE; 
                           else
                              colorOut<=BLACK;
                           end if;       
       --1st place  
                  --display 0 on score
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                         and to_integer(unsigned(playerScore) mod 10) = 0)  then
                  if (num0((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if;
                  --display 1 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 1)  then
                  if (num1((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if;
                  --display 2 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 2)  then
                  if (num2((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if; 
                  --display 3 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 3)  then
                  if (num3((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if; 
                  --display 4 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 4)  then
                  if (num4((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if; 
                  --display 5 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 5)  then
                  if (num5((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if; 
                  --display 6 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 6)  then
                  if (num6((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if; 
                  --display 7 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 7)  then
                  if (num7((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if; 
                  --display 8 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 8)  then
                  if (num8((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if; 
                  --display 9 on score 
                  elsif (to_integer(unsigned(current_y)) < 30  and to_integer(unsigned(current_x)) > 551  and to_integer(unsigned(current_x)) < 562
                      and to_integer(unsigned(playerScore) mod 10) = 9)  then
                  if (num9((to_integer(unsigned(current_y)/2)-10))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                      colorOut<=WHITE; 
                  else
                      colorOut<=BLACK;
                  end if;   
                 -- display 0 on time              
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 0)  then
                if (num0((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if; 
                --display 1 on time
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 1)  then
                if (num1((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                --display 2 on time
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 2)  then
                if (num2((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                --display 3 on playerTimer
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 3)  then
                if (num3((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                --display 4 on time
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 4)  then
                if (num4((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                --display 5 on time
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 5)  then
                if (num5((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                --display 6 on time
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 6)  then
                if (num6((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                --display 7 on time
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 7)  then
                if (num7((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                --display 8 on time
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 8)  then
                if (num8((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                --display 9 on time
                elsif ( to_integer(unsigned(current_y)) > 39 and to_integer(unsigned(current_y)) < 50 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and to_integer(unsigned(playerTimer) mod 10) = 9)  then
                if (num9((to_integer(unsigned(current_y)/2)-20))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                    colorOut<=WHITE; 
                else
                    colorOut<=BLACK;
                end if;
                     --display 0 on life 
                 elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and playerLife = "00")  then
                     if (num0((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                         colorOut<=WHITE; 
                     else
                         colorOut<=BLACK;
                     end if;
                     --display 1 on life
                  elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                         and playerLife = "01")  then
                         if (num1((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                             colorOut<=WHITE; 
                         else
                             colorOut<=BLACK;
                         end if; 
                     --display 2 on life                                                            
                 elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and playerLife = "10")  then
                             if (num2((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                 colorOut<=WHITE; 
                             else
                                 colorOut<=BLACK;
                             end if;
                     --display 3 on life
                 elsif (to_integer(unsigned(current_y)) > 59 and to_integer(unsigned(current_y)) < 70 and to_integer(unsigned(current_x)) > 551 and to_integer(unsigned(current_x)) < 562
                        and playerLife = "11")  then
                                 if (num3((to_integer(unsigned(current_y)/2)-30))((to_integer((unsigned(current_x)/2)-276))) = '1' ) then
                                     colorOut<=WHITE; 
                                 else
                                     colorOut<=BLACK;
                                 end if;
                 else
                     colorOut<=BLACK;
                  end if;
            else
                colorOut<=BLACK;
         end if;
        end if;
    else -- Off display
        colorOut <= BLACK;
    end if;
end process;

-- Process for when player moves
Player_Moves:process(rst, clk, secClock, deadKey, playerTimer)
begin
    if rising_edge(secClock) then
        if playerTimer = "0000000" then
            playerLife <= playerLife - '1';
        end if;
    end if;

    if(rst = '1') then
        chooseLevel <= "00";
        counter_move <= "000000000000000000000000"; 
        keyLock <= '0';
        deadKey <= '0';
                    player_x <= x; -- Previously "101011"; currently set to initial player location for level x
                    player_y <= y; -- Previously "101011"; same as above
                    start <= '0';
                    ScoreLock <= "00000000000000000000";
                    playerScore <= "0000000000000000";
                    playerLife <= "11"; 
                        
    elsif(clk'event and clk = '1') then
        
      
       if (player_reset = '1') then
            keyLock <= '0';
            deadKey <= '0';
            player_x <= x; -- Previously "101011"; currently set to initial player location for level x
            player_y <= y; -- Previously "101011"; same as above
            start <= '0';
            ScoreLock <= "00000000000000000000";
            playerScore <= "0000000000000000";
            
        elsif (finished = '1') then
            ScoreLock <= "00000000000000000000";
            keyLock <= '0';
            deadKey <= '0';
            player_x <= x;
            player_y <= y;
            start <= '0';
            finished <= '0';
         end if;  

        counter_move <= counter_move + '1';
        
        if (player_x /= x or player_y /= y) then
            start <= '1';
        end if;
        -- Map 1
        if (chooseMap = "000") then
            if (counter_move = "000000000000000000000000") then
            playerTimer <= playerT;
                if (btnL = '1') then
                    if ((to_integer(unsigned(player_x-1)) = 6 and to_integer(unsigned(player_y)) = 6)) then
                        keyLock <= '1';
                    end if;
                    if ((to_integer(unsigned(player_x-1)) = 3 and to_integer(unsigned(player_y)) = 15)) then
                        deadKey <= '1';
                    end if;         
                    if (to_integer(unsigned(player_x-1)) = 6 and   to_integer(unsigned(player_y)) = 3 and ScoreLock(0) = '0' )      then
                        ScoreLock(0) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 12  and to_integer(unsigned(player_y)) = 39 and ScoreLock(1) = '0')  then
                        ScoreLock(1) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 16  and to_integer(unsigned(player_y)) = 3 and ScoreLock(2) = '0' )  then
                        ScoreLock(2) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 20  and to_integer(unsigned(player_y)) = 3 and ScoreLock(3) = '0')   then
                        ScoreLock(3) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 26  and to_integer(unsigned(player_y)) = 39 and ScoreLock(4) = '0')  then
                        ScoreLock(4) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 30  and to_integer(unsigned(player_y)) = 3 and ScoreLock(5) = '0')   then
                        ScoreLock(5) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 3  and  to_integer(unsigned(player_y)) = 6 and ScoreLock(6) = '0')   then
                        ScoreLock(6) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 6  and  to_integer(unsigned(player_y)) = 16 and ScoreLock(7) = '0')  then
                        ScoreLock(7) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 11  and to_integer(unsigned(player_y)) = 6 and ScoreLock(8) = '0')   then
                        ScoreLock(8) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 15  and to_integer(unsigned(player_y)) = 6 and ScoreLock(9) = '0')   then
                        ScoreLock(9) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 28  and to_integer(unsigned(player_y)) = 39 and ScoreLock(10) = '0') then
                        ScoreLock(10) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 27  and to_integer(unsigned(player_y)) = 7 and ScoreLock(11) = '0')  then
                        ScoreLock(11) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 42  and to_integer(unsigned(player_y)) = 7 and ScoreLock(12) = '0')  then
                        ScoreLock(12) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 43  and to_integer(unsigned(player_y)) = 39 and ScoreLock(13) = '0') then
                        ScoreLock(13) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 34  and to_integer(unsigned(player_y)) = 10 and ScoreLock(14) = '0') then
                        ScoreLock(14) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 26  and to_integer(unsigned(player_y)) = 10 and ScoreLock(15) = '0') then
                        ScoreLock(15) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 22  and to_integer(unsigned(player_y)) = 11 and ScoreLock(16) = '0') then
                        ScoreLock(16) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 12  and to_integer(unsigned(player_y)) = 11 and ScoreLock(17) = '0') then
                        ScoreLock(17) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 4  and  to_integer(unsigned(player_y)) = 39 and ScoreLock(18) = '0') then
                        ScoreLock(18) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x-1)) = 3 and   to_integer(unsigned(player_y)) = 43  and ScoreLock(19) = '0' )then
                        ScoreLock(19) <= '1';
                        playerScore <= playerScore + '1'; 
                    end if;     
                    if ((to_integer(unsigned(player_x-1)) = 7 and to_integer(unsigned(player_y)) = 38) or
                        (to_integer(unsigned(player_x-1)) = 7 and to_integer(unsigned(player_y)) = 39) ) then
                        if (doorLock(0) = '0' or (to_integer(unsigned(player_x-1)) = 7 and to_integer(unsigned(player_y)) = 38)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x - '1';
                        end if;
                    elsif ((to_integer(unsigned(player_x-1)) = 16 and to_integer(unsigned(player_y)) = 38) or
                            (to_integer(unsigned(player_x-1)) = 16 and to_integer(unsigned(player_y)) = 39) ) then
                            if (doorLock(1) = '0' or (to_integer(unsigned(player_x-1)) = 16 and to_integer(unsigned(player_y)) = 38) ) then
                                player_x <= player_x;
                            else    
                                player_x <= player_x - '1';
                            end if;    
                    elsif ((to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 10) or
                           (to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 11) ) then
                        if (doorLock(3) = '0' or (to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 10)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x - '1';
                        end if; 
                    elsif ((to_integer(unsigned(player_x-1)) = 2 and to_integer(unsigned(player_y)) = 8) or
                           (to_integer(unsigned(player_x-1)) = 14 and to_integer(unsigned(player_y)) = 29)) then 
                        player_x <= player_x;                                         
                    elsif (dunWall((to_integer(unsigned(player_y)))/scale)((to_integer(unsigned(player_x-1)))/scale) = '1' ) then
                        player_x <= player_x - '1';
                    else
                        player_x <= player_x;
                    end if;
       
                elsif (btnR = '1') then
                    if ((to_integer(unsigned(player_x+1)) = 6 and to_integer(unsigned(player_y)) = 6)) then
                        keyLock <= '1';
                    end if; 
                    if ((to_integer(unsigned(player_x+1)) = 3 and to_integer(unsigned(player_y)) = 15)) then
                                            deadKey <= '1';
                                        end if; 
                    if (to_integer(unsigned(player_x+1)) = 6 and   to_integer(unsigned(player_y)) = 3 and ScoreLock(0) = '0' )      then
                        ScoreLock(0) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 12  and to_integer(unsigned(player_y)) = 39 and ScoreLock(1) = '0')  then
                        ScoreLock(1) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 16  and to_integer(unsigned(player_y)) = 3 and ScoreLock(2) = '0' )  then
                        ScoreLock(2) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 20  and to_integer(unsigned(player_y)) = 3 and ScoreLock(3) = '0')   then
                        ScoreLock(3) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 26  and to_integer(unsigned(player_y)) = 39 and ScoreLock(4) = '0')  then
                        ScoreLock(4) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 30  and to_integer(unsigned(player_y)) = 3 and ScoreLock(5) = '0')   then
                        ScoreLock(5) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 3  and  to_integer(unsigned(player_y)) = 6 and ScoreLock(6) = '0')   then
                        ScoreLock(6) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 6  and  to_integer(unsigned(player_y)) = 16 and ScoreLock(7) = '0')  then
                        ScoreLock(7) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 11  and to_integer(unsigned(player_y)) = 6 and ScoreLock(8) = '0')   then
                        ScoreLock(8) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 15  and to_integer(unsigned(player_y)) = 6 and ScoreLock(9) = '0')   then
                        ScoreLock(9) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 28  and to_integer(unsigned(player_y)) = 39 and ScoreLock(10) = '0') then
                        ScoreLock(10) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 27  and to_integer(unsigned(player_y)) = 7 and ScoreLock(11) = '0')  then
                        ScoreLock(11) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 42  and to_integer(unsigned(player_y)) = 7 and ScoreLock(12) = '0')  then
                        ScoreLock(12) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 43  and to_integer(unsigned(player_y)) = 39 and ScoreLock(13) = '0') then
                        ScoreLock(13) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 34  and to_integer(unsigned(player_y)) = 10 and ScoreLock(14) = '0') then
                        ScoreLock(14) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 26  and to_integer(unsigned(player_y)) = 10 and ScoreLock(15) = '0') then
                        ScoreLock(15) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 22  and to_integer(unsigned(player_y)) = 11 and ScoreLock(16) = '0') then
                        ScoreLock(16) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 12  and to_integer(unsigned(player_y)) = 11 and ScoreLock(17) = '0') then
                        ScoreLock(17) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 4  and  to_integer(unsigned(player_y)) = 39 and ScoreLock(18) = '0') then
                        ScoreLock(18) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x+1)) = 3 and   to_integer(unsigned(player_y)) = 43  and ScoreLock(19) = '0' )then
                        ScoreLock(19) <= '1';
                        playerScore <= playerScore + '1'; 
                    end if;     
                    if ((to_integer(unsigned(player_x+1)) = 7 and to_integer(unsigned(player_y)) = 38) or
                        (to_integer(unsigned(player_x+1)) = 7 and to_integer(unsigned(player_y)) = 39)) then
                        if (doorLock(0) = '0'or (to_integer(unsigned(player_x+1)) = 7 and to_integer(unsigned(player_y)) = 38)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x + '1';
                        end if;
                    elsif ((to_integer(unsigned(player_x+1)) = 16 and to_integer(unsigned(player_y)) = 38) or
                           (to_integer(unsigned(player_x+1)) = 16 and to_integer(unsigned(player_y)) = 39) ) then
                          if (doorLock(1) = '0' or (to_integer(unsigned(player_x+1)) = 16 and to_integer(unsigned(player_y)) = 38) ) then
                            player_x <= player_x;
                          else    
                            player_x <= player_x + '1';
                          end if;  
                    elsif ((to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 10) or
                                 (to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 11) ) then
                        if (doorLock(3) = '0' or (to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 10)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x + '1';
                        end if;  
                    elsif (dunWall((to_integer(unsigned(player_y)))/scale)((to_integer(unsigned(player_x+1)))/scale) = '1' ) then
                        player_x <= player_x + '1';
                    else
                        player_x <= player_x;
                    end if;        
                elsif (btnD = '1') then
                    if ((to_integer(unsigned(player_x)) = 6 and to_integer(unsigned(player_y+1)) = 6)) then
                    keyLock <= '1';
                end if;  
                if ((to_integer(unsigned(player_x)) = 3 and to_integer(unsigned(player_y+1)) = 15)) then
                                    deadKey <= '1';
                                end if;  
                                
                if (to_integer(unsigned(player_x)) = 6 and   to_integer(unsigned(player_y+1)) = 3 and ScoreLock(0) = '0' )      then
                    ScoreLock(0) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 12  and to_integer(unsigned(player_y+1)) = 39 and ScoreLock(1) = '0')  then
                    ScoreLock(1) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 16  and to_integer(unsigned(player_y+1)) = 3 and ScoreLock(2) = '0' )  then
                    ScoreLock(2) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 20  and to_integer(unsigned(player_y+1)) = 3 and ScoreLock(3) = '0')   then
                    ScoreLock(3) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 26  and to_integer(unsigned(player_y+1)) = 39 and ScoreLock(4) = '0')  then
                    ScoreLock(4) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 30  and to_integer(unsigned(player_y+1)) = 3 and ScoreLock(5) = '0')   then
                    ScoreLock(5) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 3  and  to_integer(unsigned(player_y+1)) = 6 and ScoreLock(6) = '0')   then
                    ScoreLock(6) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 6  and  to_integer(unsigned(player_y+1)) = 16 and ScoreLock(7) = '0')  then
                    ScoreLock(7) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 11  and to_integer(unsigned(player_y+1)) = 6 and ScoreLock(8) = '0')   then
                    ScoreLock(8) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 15  and to_integer(unsigned(player_y+1)) = 6 and ScoreLock(9) = '0')   then
                    ScoreLock(9) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 28  and to_integer(unsigned(player_y+1)) = 39 and ScoreLock(10) = '0') then
                    ScoreLock(10) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 27  and to_integer(unsigned(player_y+1)) = 7 and ScoreLock(11) = '0')  then
                    ScoreLock(11) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 42  and to_integer(unsigned(player_y+1)) = 7 and ScoreLock(12) = '0')  then
                    ScoreLock(12) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 43  and to_integer(unsigned(player_y+1)) = 39 and ScoreLock(13) = '0') then
                    ScoreLock(13) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 34  and to_integer(unsigned(player_y+1)) = 10 and ScoreLock(14) = '0') then
                    ScoreLock(14) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 26  and to_integer(unsigned(player_y+1)) = 10 and ScoreLock(15) = '0') then
                    ScoreLock(15) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 22  and to_integer(unsigned(player_y+1)) = 11 and ScoreLock(16) = '0') then
                    ScoreLock(16) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 12  and to_integer(unsigned(player_y+1)) = 11 and ScoreLock(17) = '0') then
                    ScoreLock(17) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 4  and  to_integer(unsigned(player_y+1)) = 39 and ScoreLock(18) = '0') then
                    ScoreLock(18) <= '1';
                    playerScore <= playerScore + '1'; 
                elsif (to_integer(unsigned(player_x)) = 3 and   to_integer(unsigned(player_y+1)) = 43  and ScoreLock(19) = '0' )then
                    ScoreLock(19) <= '1';
                    playerScore <= playerScore + '1'; 
                end if;                                    
                   if ((to_integer(unsigned(player_x)) = 2 and to_integer(unsigned(player_y+1)) = 8) or
                        (to_integer(unsigned(player_x)) = 3 and to_integer(unsigned(player_y+1)) = 8)) then
                        if (doorLock(4) = '0' or (to_integer(unsigned(player_x)) = 2 and to_integer(unsigned(player_y+1)) = 8)) then
                            player_y <= player_y;
                        else    
                            player_y <= player_y + '1';
                        end if;
                   elsif ((to_integer(unsigned(player_x)) = 14 and to_integer(unsigned(player_y+1)) = 29) or
                        (to_integer(unsigned(player_x)) = 15 and to_integer(unsigned(player_y+1)) = 29)) then
                            if (doorLock(2) = '0' or (to_integer(unsigned(player_x)) = 14 and to_integer(unsigned(player_y+1)) = 29)) then
                                player_y <= player_y;
                            else    
                                player_y <= player_y + '1';
                            end if;
                    elsif (dunWall((to_integer(unsigned(player_y+1)))/scale)((to_integer(unsigned(player_x)))/scale) = '1' ) then
                        player_y <= player_y + '1';
                    else
                        player_y <= player_y;
                    end if;
                elsif (btnU = '1') then
                    if ((to_integer(unsigned(player_x)) = 6 and to_integer(unsigned(player_y-1)) = 6)) then
                        keyLock <= '1';
                    end if;
                    if ((to_integer(unsigned(player_x)) = 3 and to_integer(unsigned(player_y-1)) = 15)) then
                                            deadKey <= '1';
                                        end if; 
                    if (to_integer(unsigned(player_x)) = 6 and   to_integer(unsigned(player_y-1)) = 3 and ScoreLock(0) = '0' )      then
                        ScoreLock(0) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 12  and to_integer(unsigned(player_y-1)) = 39 and ScoreLock(1) = '0')  then
                        ScoreLock(1) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 16  and to_integer(unsigned(player_y-1)) = 3 and ScoreLock(2) = '0' )  then
                        ScoreLock(2) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 20  and to_integer(unsigned(player_y-1)) = 3 and ScoreLock(3) = '0')   then
                        ScoreLock(3) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 26  and to_integer(unsigned(player_y-1)) = 39 and ScoreLock(4) = '0')  then
                        ScoreLock(4) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 30  and to_integer(unsigned(player_y-1)) = 3 and ScoreLock(5) = '0')   then
                        ScoreLock(5) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 3  and  to_integer(unsigned(player_y-1)) = 6 and ScoreLock(6) = '0')   then
                        ScoreLock(6) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 6  and  to_integer(unsigned(player_y-1)) = 16 and ScoreLock(7) = '0')  then
                        ScoreLock(7) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 11  and to_integer(unsigned(player_y-1)) = 6 and ScoreLock(8) = '0')   then
                        ScoreLock(8) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 15  and to_integer(unsigned(player_y-1)) = 6 and ScoreLock(9) = '0')   then
                        ScoreLock(9) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 28  and to_integer(unsigned(player_y-1)) = 39 and ScoreLock(10) = '0') then
                        ScoreLock(10) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 27  and to_integer(unsigned(player_y-1)) = 7 and ScoreLock(11) = '0')  then
                        ScoreLock(11) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 42  and to_integer(unsigned(player_y-1)) = 7 and ScoreLock(12) = '0')  then
                        ScoreLock(12) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 43  and to_integer(unsigned(player_y-1)) = 39 and ScoreLock(13) = '0') then
                        ScoreLock(13) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 34  and to_integer(unsigned(player_y-1)) = 10 and ScoreLock(14) = '0') then
                        ScoreLock(14) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 26  and to_integer(unsigned(player_y-1)) = 10 and ScoreLock(15) = '0') then
                        ScoreLock(15) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 22  and to_integer(unsigned(player_y-1)) = 11 and ScoreLock(16) = '0') then
                        ScoreLock(16) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 12  and to_integer(unsigned(player_y-1)) = 11 and ScoreLock(17) = '0') then
                        ScoreLock(17) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 4  and  to_integer(unsigned(player_y-1)) = 39 and ScoreLock(18) = '0') then
                        ScoreLock(18) <= '1';
                        playerScore <= playerScore + '1'; 
                    elsif (to_integer(unsigned(player_x)) = 3 and   to_integer(unsigned(player_y-1)) = 43  and ScoreLock(19) = '0' )then
                        ScoreLock(19) <= '1';
                        playerScore <= playerScore + '1'; 
                    end if;                         
                    if ((to_integer(unsigned(player_x)) = 10 and to_integer(unsigned(player_y-1)) = 4) or
                        (to_integer(unsigned(player_x)) = 11 and to_integer(unsigned(player_y-1)) = 4)) then
                        if (keyLock = '0') then
                            player_y <= player_y;
                        else    
                            player_y <= player_y - '1';
                        end if;  
                    elsif ((to_integer(unsigned(player_x)) = 2 and to_integer(unsigned(player_y-1)) = 8) or
                            (to_integer(unsigned(player_x)) = 3 and to_integer(unsigned(player_y-1)) = 8)) then
                            if (doorLock(4) = '0' or (to_integer(unsigned(player_x)) = 2 and to_integer(unsigned(player_y-1)) = 8) ) then
                                player_y <= player_y;
                            else    
                                player_y <= player_y - '1';
                            end if;   
                    elsif ((to_integer(unsigned(player_x)) = 14 and to_integer(unsigned(player_y-1)) = 29) or
                            (to_integer(unsigned(player_x)) = 15 and to_integer(unsigned(player_y-1)) = 29)) then
                            if (doorLock(2) = '0' or (to_integer(unsigned(player_x)) = 14 and to_integer(unsigned(player_y-1)) = 29)) then
                                player_y <= player_y;
                            else    
                                player_y <= player_y - '1';
                            end if;
                    elsif ((to_integer(unsigned(player_x)) = 7 and to_integer(unsigned(player_y-1)) = 38) or
                             (to_integer(unsigned(player_x)) = 16 and to_integer(unsigned(player_y-1)) = 38) or
                             (to_integer(unsigned(player_x)) = 21 and to_integer(unsigned(player_y-1)) = 10)) then 
                        player_y <= player_y;     
                    elsif (dunWall((to_integer(unsigned(player_y-1)))/scale)((to_integer(unsigned(player_x)))/scale) = '1' ) then
                        player_y <= player_y - '1';
                    else
                        player_y <= player_y;
                    end if;    
                end if;
                if ((player_x = x_end or player_x = (x_end - '1')) and (player_y = y_end or player_y = (y_end - '1'))) then
                    ChooseLevel <= ChooseLevel + '1';
                    finished <= '1';
                end if;        
            end if;
        elsif (chooseMap = "111") then
                if (counter_move = "000000000000000000000000") then
                playerTimer <= playerT;

                    if (btnL = '1') then
                    if ((to_integer(unsigned(player_x-1)) = 2 and to_integer(unsigned(player_y)) = 26)) then
                        keyLock <= '1';
                    end if;
                    if ((to_integer(unsigned(player_x-1)) = 39 and to_integer(unsigned(player_y)) = 35)) then
                                            deadKey <= '1';
                                        end if;    
					if (to_integer(unsigned(player_x-1)) = 5  and  to_integer(unsigned(player_y)) = 2 and ScoreLock(0) = '0' )    then
                        ScoreLock(0) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 10  and to_integer(unsigned(player_y)) = 2 and ScoreLock(1) = '0' )   then
                        ScoreLock(1) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 15  and to_integer(unsigned(player_y)) = 2 and ScoreLock(2) = '0' )   then
                        ScoreLock(2) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 22  and to_integer(unsigned(player_y)) = 4 and ScoreLock(3) = '0' )   then
                        ScoreLock(3) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 43  and to_integer(unsigned(player_y)) = 4 and ScoreLock(4) = '0' )   then
                        ScoreLock(4) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 7  and  to_integer(unsigned(player_y)) = 7 and ScoreLock(5) = '0')     then
                        ScoreLock(5) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 17  and to_integer(unsigned(player_y)) = 7 and ScoreLock(6) = '0')    then
                        ScoreLock(6) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 27  and to_integer(unsigned(player_y)) = 7 and ScoreLock(7) = '0')    then
                        ScoreLock(7) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 30  and to_integer(unsigned(player_y)) = 8 and ScoreLock(8) = '0')    then
                        ScoreLock(8) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 27 and  to_integer(unsigned(player_y)) = 9 and ScoreLock(9) = '0' )    then
                        ScoreLock(9) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 32 and  to_integer(unsigned(player_y)) = 10 and ScoreLock(10) = '0' )  then
                        ScoreLock(10) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 7 and   to_integer(unsigned(player_y)) = 28 and ScoreLock(11) = '0')    then
                        ScoreLock(11) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 17  and to_integer(unsigned(player_y)) = 29 and ScoreLock(12) = '0' ) then
                        ScoreLock(12) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 25  and to_integer(unsigned(player_y)) = 30 and ScoreLock(13) = '0' ) then
                        ScoreLock(13) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 27  and to_integer(unsigned(player_y)) = 32 and ScoreLock(14) = '0' ) then
                        ScoreLock(14) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 3  and  to_integer(unsigned(player_y)) = 43 and ScoreLock(15) = '0' )  then
                        ScoreLock(15) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 7  and  to_integer(unsigned(player_y)) = 43 and ScoreLock(16) = '0' )  then
                        ScoreLock(16) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) =  20 and to_integer(unsigned(player_y)) = 42 and ScoreLock(17) = '0') then
                        ScoreLock(17) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 33 and  to_integer(unsigned(player_y)) = 42 and ScoreLock(18) = '0' )  then
                        ScoreLock(18) <= '1';
                        playerScore <= playerScore + '1';
                    elsif (to_integer(unsigned(player_x-1)) = 43 and  to_integer(unsigned(player_y)) = 28 and ScoreLock(19) = '0' ) then 
                        ScoreLock(19) <= '1';
                        playerScore <= playerScore + '1'; 
                     end if; 
                        if ((to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 6) or
                              (to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 7)) then
                            if (doorLock(0) = '0' or (to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 6)) then
                                player_x <= player_x;
                            else    
                                player_x <= player_x - '1';
                            end if; 
                        elsif ((to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 14) or
                                  (to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 15)) then
                                if (doorLock(1) = '0' or (to_integer(unsigned(player_x-1)) = 21 and to_integer(unsigned(player_y)) = 14)) then
                                    player_x <= player_x;
                                else    
                                    player_x <= player_x - '1';
                                end if;  
                        elsif ((to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 30) or
                                      (to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 31)) then
                                    if (doorLock(2) = '0' or (to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 30)) then
                                        player_x <= player_x;
                                    else    
                                        player_x <= player_x - '1';
                                    end if;  
                        elsif ((to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 34) or
                                          (to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 35)) then
                                        if (doorLock(3) = '0' or (to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 34)) then
                                            player_x <= player_x;
                                        else    
                                            player_x <= player_x - '1';
                                        end if;  
                        elsif ((to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 22) or
                                              (to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 23)) then
                                            if (doorLock(4) = '0' or (to_integer(unsigned(player_x-1)) = 13 and to_integer(unsigned(player_y)) = 22)) then
                                                player_x <= player_x;
                                            else    
                                                player_x <= player_x - '1';
                                            end if;  
                        elsif ((to_integer(unsigned(player_x-1)) = 34 and to_integer(unsigned(player_y)) = 36)) then
                            player_x <= player_x;                                                        
                        elsif (dunWall2(to_integer(unsigned(player_y)))(to_integer(unsigned(player_x-1))) = '1' ) then
                            player_x <= player_x - '1';
                        else
                            player_x <= player_x;
                        end if;
                    elsif (btnR = '1') then
                    if ((to_integer(unsigned(player_x+1)) = 2 and to_integer(unsigned(player_y)) = 26)) then
                                            keyLock <= '1';
                                        end if;
                   if ((to_integer(unsigned(player_x+1)) = 39 and to_integer(unsigned(player_y)) = 35)) then
                                             deadKey <= '1';
                                       end if;  
										if (to_integer(unsigned(player_x+1)) = 5  and  to_integer(unsigned(player_y)) = 2 and ScoreLock(0) = '0' )    then
                                            ScoreLock(0) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 10  and to_integer(unsigned(player_y)) = 2 and ScoreLock(1) = '0' )   then
                                            ScoreLock(1) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 15  and to_integer(unsigned(player_y)) = 2 and ScoreLock(2) = '0' )   then
                                            ScoreLock(2) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 22  and to_integer(unsigned(player_y)) = 4 and ScoreLock(3) = '0' )   then
                                            ScoreLock(3) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 43  and to_integer(unsigned(player_y)) = 4 and ScoreLock(4) = '0' )   then
                                            ScoreLock(4) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 7  and  to_integer(unsigned(player_y)) = 7 and ScoreLock(5) = '0')     then
                                            ScoreLock(5) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 17  and to_integer(unsigned(player_y)) = 7 and ScoreLock(6) = '0')    then
                                            ScoreLock(6) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 27  and to_integer(unsigned(player_y)) = 7 and ScoreLock(7) = '0')    then
                                            ScoreLock(7) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 30  and to_integer(unsigned(player_y)) = 8 and ScoreLock(8) = '0')    then
                                            ScoreLock(8) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 27 and  to_integer(unsigned(player_y)) = 9 and ScoreLock(9) = '0' )    then
                                            ScoreLock(9) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 32 and  to_integer(unsigned(player_y)) = 10 and ScoreLock(10) = '0' )  then
                                            ScoreLock(10) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 7 and   to_integer(unsigned(player_y)) = 28 and ScoreLock(11) = '0')    then
                                            ScoreLock(11) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 17  and to_integer(unsigned(player_y)) = 29 and ScoreLock(12) = '0' ) then
                                            ScoreLock(12) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 25  and to_integer(unsigned(player_y)) = 30 and ScoreLock(13) = '0' ) then
                                            ScoreLock(13) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 27  and to_integer(unsigned(player_y)) = 32 and ScoreLock(14) = '0' ) then
                                            ScoreLock(14) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 3  and  to_integer(unsigned(player_y)) = 43 and ScoreLock(15) = '0' )  then
                                            ScoreLock(15) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 7  and  to_integer(unsigned(player_y)) = 43 and ScoreLock(16) = '0' )  then
                                            ScoreLock(16) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) =  20 and to_integer(unsigned(player_y)) = 42 and ScoreLock(17) = '0') then
                                            ScoreLock(17) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 33 and  to_integer(unsigned(player_y)) = 42 and ScoreLock(18) = '0' )  then
                                            ScoreLock(18) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x+1)) = 43 and  to_integer(unsigned(player_y)) = 28 and ScoreLock(19) = '0' ) then
                                            ScoreLock(19) <= '1';
                                            playerScore <= playerScore + '1'; 
                                         end if;
                        if ((to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 6) or
                          (to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 7)) then
                        if (doorLock(0) = '0' or (to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 6)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x + '1';
                        end if; 
                        elsif ((to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 14) or
                          (to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 15)) then
                        if (doorLock(1) = '0' or (to_integer(unsigned(player_x+1)) = 21 and to_integer(unsigned(player_y)) = 14)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x + '1';
                        end if; 
                        elsif ((to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 30) or
                          (to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 31)) then
                        if (doorLock(2) = '0' or (to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 30)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x + '1';
                        end if; 
                        elsif ((to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 34) or
                          (to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 35)) then
                        if (doorLock(3) = '0' or (to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 34)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x + '1';
                        end if; 
                        elsif ((to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 22) or
                          (to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 23)) then
                        if (doorLock(4) = '0' or (to_integer(unsigned(player_x+1)) = 13 and to_integer(unsigned(player_y)) = 22)) then
                            player_x <= player_x;
                        else    
                            player_x <= player_x + '1';
                        end if;      
                        elsif (dunWall2(to_integer(unsigned(player_y)))(to_integer(unsigned(player_x+1))) = '1' ) then
                            player_x <= player_x + '1';
                        else
                            player_x <= player_x;
                        end if;        
                    elsif (btnD = '1') then
                    if ((to_integer(unsigned(player_x)) = 2 and to_integer(unsigned(player_y+1)) = 26)) then
                        keyLock <= '1';
                    end if;
                    if ((to_integer(unsigned(player_x)) = 39 and to_integer(unsigned(player_y+1)) = 35)) then
                                            deadKey <= '1';
                                        end if;
if (to_integer(unsigned(player_x)) = 5  and  to_integer(unsigned(player_y+1)) = 2 and ScoreLock(0) = '0' )    then
                                            ScoreLock(0) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 10  and to_integer(unsigned(player_y+1)) = 2 and ScoreLock(1) = '0' )   then
                                            ScoreLock(1) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 15  and to_integer(unsigned(player_y+1)) = 2 and ScoreLock(2) = '0' )   then
                                            ScoreLock(2) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 22  and to_integer(unsigned(player_y+1)) = 4 and ScoreLock(3) = '0' )   then
                                            ScoreLock(3) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 43  and to_integer(unsigned(player_y+1)) = 4 and ScoreLock(4) = '0' )   then
                                            ScoreLock(4) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 7  and  to_integer(unsigned(player_y+1)) = 7 and ScoreLock(5) = '0')     then
                                            ScoreLock(5) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 17  and to_integer(unsigned(player_y+1)) = 7 and ScoreLock(6) = '0')    then
                                            ScoreLock(6) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 27  and to_integer(unsigned(player_y+1)) = 7 and ScoreLock(7) = '0')    then
                                            ScoreLock(7) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 30  and to_integer(unsigned(player_y+1)) = 8 and ScoreLock(8) = '0')    then
                                            ScoreLock(8) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 27 and  to_integer(unsigned(player_y+1)) = 9 and ScoreLock(9) = '0' )    then
                                            ScoreLock(9) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 32 and  to_integer(unsigned(player_y+1)) = 10 and ScoreLock(10) = '0' )  then
                                            ScoreLock(10) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 7 and   to_integer(unsigned(player_y+1)) = 28 and ScoreLock(11) = '0')    then
                                            ScoreLock(11) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 17  and to_integer(unsigned(player_y+1)) = 29 and ScoreLock(12) = '0' ) then
                                            ScoreLock(12) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 25  and to_integer(unsigned(player_y+1)) = 30 and ScoreLock(13) = '0' ) then
                                            ScoreLock(13) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 27  and to_integer(unsigned(player_y+1)) = 32 and ScoreLock(14) = '0' ) then
                                            ScoreLock(14) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 3  and  to_integer(unsigned(player_y+1)) = 43 and ScoreLock(15) = '0' )  then
                                            ScoreLock(15) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 7  and  to_integer(unsigned(player_y+1)) = 43 and ScoreLock(16) = '0' )  then
                                            ScoreLock(16) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) =  20 and to_integer(unsigned(player_y+1)) = 42 and ScoreLock(17) = '0') then
                                            ScoreLock(17) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 33 and  to_integer(unsigned(player_y+1)) = 42 and ScoreLock(18) = '0' )  then
                                            ScoreLock(18) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 43 and  to_integer(unsigned(player_y+1)) = 28 and ScoreLock(19) = '0' ) then
                                            ScoreLock(19) <= '1';
                                            playerScore <= playerScore + '1'; 
                                         end if; 
                        if ((to_integer(unsigned(player_x)) = 34 and to_integer(unsigned(player_y+1)) = 36) or
                          (to_integer(unsigned(player_x)) = 35 and to_integer(unsigned(player_y+1)) = 36)) then
                            if (doorLock(5) = '0' or (to_integer(unsigned(player_x)) = 34 and to_integer(unsigned(player_y+1)) = 36)) then
                                player_y <= player_y;
                            else    
                                player_y <= player_y + '1';
                            end if;           
                        elsif (dunWall2(to_integer(unsigned(player_y+1)))(to_integer(unsigned(player_x))) = '1' ) then
                            player_y <= player_y + '1';
                        else
                            player_y <= player_y;
                        end if;
                    elsif (btnU = '1') then
                    if ((to_integer(unsigned(player_x)) = 2 and to_integer(unsigned(player_y-1)) = 26)) then
                        keyLock <= '1';
                    end if;
                    if ((to_integer(unsigned(player_x)) = 39 and to_integer(unsigned(player_y-1)) = 35)) then
                                            deadKey <= '1';
                                        end if;
if (to_integer(unsigned(player_x)) = 5  and  to_integer(unsigned(player_y-1)) = 2 and ScoreLock(0) = '0' )    then
                                            ScoreLock(0) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 10  and to_integer(unsigned(player_y-1)) = 2 and ScoreLock(1) = '0' )   then
                                            ScoreLock(1) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 15  and to_integer(unsigned(player_y-1)) = 2 and ScoreLock(2) = '0' )   then
                                            ScoreLock(2) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 22  and to_integer(unsigned(player_y-1)) = 4 and ScoreLock(3) = '0' )   then
                                            ScoreLock(3) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 43  and to_integer(unsigned(player_y-1)) = 4 and ScoreLock(4) = '0' )   then
                                            ScoreLock(4) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 7  and  to_integer(unsigned(player_y-1)) = 7 and ScoreLock(5) = '0')     then
                                            ScoreLock(5) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 17  and to_integer(unsigned(player_y-1)) = 7 and ScoreLock(6) = '0')    then
                                            ScoreLock(6) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 27  and to_integer(unsigned(player_y-1)) = 7 and ScoreLock(7) = '0')    then
                                            ScoreLock(7) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 30  and to_integer(unsigned(player_y-1)) = 8 and ScoreLock(8) = '0')    then
                                            ScoreLock(8) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 27 and  to_integer(unsigned(player_y-1)) = 9 and ScoreLock(9) = '0' )    then
                                            ScoreLock(9) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 32 and  to_integer(unsigned(player_y-1)) = 10 and ScoreLock(10) = '0' )  then
                                            ScoreLock(10) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 7 and   to_integer(unsigned(player_y-1)) = 28 and ScoreLock(11) = '0')    then
                                            ScoreLock(11) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 17  and to_integer(unsigned(player_y-1)) = 29 and ScoreLock(12) = '0' ) then
                                            ScoreLock(12) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 25  and to_integer(unsigned(player_y-1)) = 30 and ScoreLock(13) = '0' ) then
                                            ScoreLock(13) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 27  and to_integer(unsigned(player_y-1)) = 32 and ScoreLock(14) = '0' ) then
                                            ScoreLock(14) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 3  and  to_integer(unsigned(player_y-1)) = 43 and ScoreLock(15) = '0' )  then
                                            ScoreLock(15) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 7  and  to_integer(unsigned(player_y-1)) = 43 and ScoreLock(16) = '0' )  then
                                            ScoreLock(16) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) =  20 and to_integer(unsigned(player_y-1)) = 42 and ScoreLock(17) = '0') then
                                            ScoreLock(17) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 33 and  to_integer(unsigned(player_y-1)) = 42 and ScoreLock(18) = '0' )  then
                                            ScoreLock(18) <= '1';
                                            playerScore <= playerScore + '1';
                                        elsif (to_integer(unsigned(player_x)) = 43 and  to_integer(unsigned(player_y-1)) = 28 and ScoreLock(19) = '0' ) then
                                            ScoreLock(19) <= '1';
                                            playerScore <= playerScore + '1'; 
                                         end if;                                         
                        if ((to_integer(unsigned(player_x)) = 34 and to_integer(unsigned(player_y-1)) = 36) or
                          (to_integer(unsigned(player_x)) = 35 and to_integer(unsigned(player_y-1)) = 36)) then
                            if (doorLock(5) = '0' or (to_integer(unsigned(player_x)) = 34 and to_integer(unsigned(player_y-1)) = 36)) then
                                player_y <= player_y;
                            else    
                                player_y <= player_y - '1';
                            end if; 
    elsif ((to_integer(unsigned(player_x)) = 8 and to_integer(unsigned(player_y-1)) = 38) or
                                                      (to_integer(unsigned(player_x)) = 8 and to_integer(unsigned(player_y-1)) = 39)) then
                                                        
                                                        if (keyLock = '0') then
                                                            player_y <= player_y;
                                                        else    
                                                            player_y <= player_y - '1';
                                                        end if; 
                        elsif ((to_integer(unsigned(player_x)) = 21 and to_integer(unsigned(player_y-1)) = 6) or
                               (to_integer(unsigned(player_x)) = 21 and to_integer(unsigned(player_y-1)) = 14)or
                               (to_integer(unsigned(player_x)) = 13 and to_integer(unsigned(player_y-1)) = 30) or
                               (to_integer(unsigned(player_x)) = 13 and to_integer(unsigned(player_y-1)) = 34)or
                               (to_integer(unsigned(player_x)) = 13 and to_integer(unsigned(player_y-1)) = 22)) then 
                               player_y <= player_y;
                        elsif (dunWall2(to_integer(unsigned(player_y-1)))(to_integer(unsigned(player_x))) = '1' ) then
                            player_y <= player_y - '1';
                        else
                            player_y <= player_y;
                        end if;    
                    end if;
                    if ((player_x = x_end or player_x = (x_end - '1')) and (player_y = y_end or player_y = (y_end - '1'))) then
                        ChooseLevel <= "00";
                        finished <= '1';
                    end if;        
                end if;
        end if;
	end if;
end process;
end Behavioral;
