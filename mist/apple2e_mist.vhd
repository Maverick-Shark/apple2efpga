--
-- mist_top.vhd.vhd
--
-- Apple II+ toplevel for the MiST board
-- https://github.com/wsoltys/mist_apple2
--
-- Copyright (c) 2014 W. Soltys <wsoltys@gmail.com>
--
-- This source file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This source file is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Modified with Z80 Softcard implementation based on system.v (a2e128 core)
-- by Jesus Arias
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library mist;
use mist.mist.all;

entity apple2e_mist is
  generic
  (
    VGA_BITS   : integer := 6;
    BIG_OSD : boolean := false;
    HDMI : boolean := false;
    BUILD_DATE : string :=""
  );
  port (
    -- Clocks
    CLOCK_IN    : in std_logic;

    -- SDRAM
    SDRAM_nCS : out std_logic; -- Chip Select
    SDRAM_DQ : inout std_logic_vector(15 downto 0); -- SDRAM Data bus 16 Bits
    SDRAM_A : out std_logic_vector(12 downto 0); -- SDRAM Address bus 13 Bits
    SDRAM_DQMH : out std_logic; -- SDRAM High Data Mask
    SDRAM_DQML : out std_logic; -- SDRAM Low-byte Data Mask
    SDRAM_nWE : out std_logic; -- SDRAM Write Enable
    SDRAM_nCAS : out std_logic; -- SDRAM Column Address Strobe
    SDRAM_nRAS : out std_logic; -- SDRAM Row Address Strobe
    SDRAM_BA : out std_logic_vector(1 downto 0); -- SDRAM Bank Address
    SDRAM_CLK : out std_logic; -- SDRAM Clock
    SDRAM_CKE: out std_logic; -- SDRAM Clock Enable
    
    -- SPI
    SPI_SCK : in std_logic;
    SPI_DI : in std_logic;
    SPI_DO : inout std_logic;
    SPI_SS2 : in std_logic;
    SPI_SS3 : in std_logic;
    SPI_SS4 : in std_logic;
    CONF_DATA0 : in std_logic;

    -- VGA output
    VGA_HS,                                             -- H_SYNC
    VGA_VS : out std_logic;                             -- V_SYNC
    VGA_R,                                              -- Red[x:0]
    VGA_G,                                              -- Green[x:0]
    VGA_B : out std_logic_vector(VGA_BITS-1 downto 0);  -- Blue[x:0]

    -- HDMI
    HDMI_R     : out   std_logic_vector(7 downto 0) := (others => '0');
    HDMI_G     : out   std_logic_vector(7 downto 0) := (others => '0');
    HDMI_B     : out   std_logic_vector(7 downto 0) := (others => '0');
    HDMI_HS    : out   std_logic := '0';
    HDMI_VS    : out   std_logic := '0';
    HDMI_DE    : out   std_logic := '0';
    HDMI_PCLK  : out   std_logic := '0';
    HDMI_SCL   : inout std_logic;
    HDMI_SDA   : inout std_logic;

    -- Audio
    AUDIO_L,
    AUDIO_R    : out std_logic;
    I2S_BCK    : out   std_logic;
    I2S_LRCK   : out   std_logic;
    I2S_DATA   : out   std_logic;
    SPDIF_O    : out   std_logic;

    AUDIO_IN   : in std_logic;

    -- UART
    UART_RX : in std_logic;
    UART_TX : out std_logic;
    UART_CTS: in std_logic;
    UART_RTS: out std_logic;

    -- LEDG
    LED : out std_logic

    );

end apple2e_mist;

architecture datapath of apple2e_mist is

  function SEP return string is
  begin
	  if BIG_OSD then return "-;"; else return ""; end if;
  end function;

  function USER_IO_FEAT return std_logic_vector is
  variable feat: std_logic_vector(31 downto 0);
  begin
    feat := x"00000050"; -- Primary master/slave IDE
    if BIG_OSD then feat := feat or x"00002000"; end if;
    if HDMI    then feat := feat or x"00004000"; end if;
    return feat;
  end function;

  function to_slv(s: string) return std_logic_vector is 
    constant ss: string(1 to s'length) := s; 
    variable rval: std_logic_vector(1 to 8 * s'length); 
    variable p: integer; 
    variable c: integer; 
  
  begin 
    for i in ss'range loop
      p := 8 * i;
      c := character'pos(ss(i));
      rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
    end loop; 
    return rval; 
  end function; 

  -- OSD Configuration String
  -- Bits de status usados:
  -- status(0)   : Cold reset (active high pulse)
  -- status(1)   : CPU Type (0=6502, 1=65C02)
  -- status(3:2) : Monitor mode (00=Color, 01=B&W, 10=Green, 11=Amber)
  -- status(4)   : Machine Type (0=NTSC, 1=PAL)
  -- status(5)   : Joysticks swap
  -- status(7)   : Reset (active high pulse)
  -- status(9:8) : Write Protect (00=None, 01=Disk0, 10=Disk1, 11=Both)
  -- status(10)  : CFFA 2.0 enable
  -- status(12:11): Scanlines
  -- status(14:13): Color palette
  -- status(15)  : SSC Enable
  -- status(19:16): SSC Baud Rate
  -- status(20)  : SSC Data Bits
  -- status(22:21): SSC Parity
  -- status(23)  : SSC LF after CR
  -- status(25:24): Slot 5 (00=Mouse, 01=Mockingboard, 10/11=Empty)
  -- status(26)  : Disk Drive sound (active low = Yes)
  -- status(28:27): Slot 4 (00=Mockingboard, 01=Softcard, 10=Mouse, 11=Empty)
  -- status(32)  : Save CFFA settings
  
  constant CONF_STR : string :=
   "AppleII;;"&
   "S2U,NIB,Load Disk 0;"&
   "S3U,NIB,Load Disk 1;"&
   "S0U,HD?VHDHDV,Mount IDE0;"&
   "S1U,HD?VHDHDV,Mount IDE1;"&
   SEP&
   "O89,Write Protect,None,Disk 0,Disk 1, Disk 0&1;"&
   "O1,CPU Type,6502,65C02;"&
   "O23,Monitor,Color,B&W,Green,Amber;"&
   "ODE,Color palette,//e,IIgs,AppleWin,apple2fpga;"&
   "O4,Machine Type,NTSC,PAL;"&
   "OBC,Scanlines,Off,25%,50%,75%;"&
   "O5,Joysticks,Normal,Swapped;"&
   -- "OQ,Disk Drive sound,Yes,No;"&
   SEP&
   "P1,Super Serial S2;"&
   "ORS,Slot 4,Mockingboard,Softcard,Mouse,Empty;"&
   "OOP,Slot 5,Mouse,Mockingboard,Empty;"&
   "OA,CFFA 2.0     S7,Off,On;"&
   "P1OF,SSC,Disable,Enable;"&
   "P1OGJ,Baud Rate,115200,50,75,110,135,150,300,600,1200,1800,2400,3600,4800,7200,9600,19200;"&
   "P1OK,Data Bits,8,7;"&
   "P1OLM,Parity,Off,Odd,Even;"&
   "P1ON,Generate LF after CR,Off,On;"&
   SEP&
   "R32,Save CFFA settings;"&
   "T7,Reset;"&
   "T0,Cold reset;"&
   "V,v"&BUILD_DATE;

  component mist_sd_card
    port (
            sd_lba         : out std_logic_vector(31 downto 0);
            sd_rd          : out std_logic;
            sd_wr          : out std_logic;
            sd_ack         : in  std_logic;

            sd_buff_addr   : in  std_logic_vector(8 downto 0);
            sd_buff_dout   : in  std_logic_vector(7 downto 0);
            sd_buff_din    : out std_logic_vector(7 downto 0);
            sd_buff_wr     : in  std_logic;

            ram_addr       : in  unsigned(12 downto 0);
            ram_di         : in  unsigned( 7 downto 0);
            ram_do         : out unsigned( 7 downto 0);
            ram_we         : in  std_logic;

            change         : in  std_logic;                     -- Force reload as disk may have changed
            mount          : in  std_logic;                     -- umount(0)/mount(1)
            track          : in  std_logic_vector(5 downto 0);  -- Track number (0-34)
            busy           : out std_logic;
            ready          : out std_logic;
            active         : in  std_logic;

            clk            : in  std_logic;     -- System clock
            reset          : in  std_logic
        );
  end component mist_sd_card;

  component sdram is
    port( sd_data : inOut std_logic_vector(15 downto 0);
          sd_addr : out std_logic_vector(12 downto 0);
          sd_dqm : out std_logic_vector(1 downto 0);
          sd_ba : out std_logic_vector(1 downto 0);
          sd_cs : out std_logic;
          sd_we : out std_logic;
          sd_ras : out std_logic;
          sd_cas : out std_logic;
          init_n : in std_logic;
          clk : in std_logic;
          clkref : in std_logic;
          din : in std_logic_vector(7 downto 0);
          dout : out std_logic_vector(15 downto 0);
          aux : in std_logic;
          addr : in std_logic_vector(24 downto 0);
          we : in std_logic
    );
  end component;

  component i2s
  generic (
    I2S_Freq   : integer := 48000;
    AUDIO_DW   : integer := 16
  );
  port
  (
    clk        : in    std_logic;
    reset      : in    std_logic;
    clk_rate   : in    integer;
    sclk       : out   std_logic;
    lrclk      : out   std_logic;
    sdata      : out   std_logic;
    left_chan  : in    std_logic_vector(AUDIO_DW-1 downto 0);
    right_chan : in    std_logic_vector(AUDIO_DW-1 downto 0)
  );
  end component i2s;

  component spdif port
  (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;
    clk_rate_i : in    integer;
    spdif_o    : out   std_logic;
    sample_i   : in    std_logic_vector(31 downto 0)
  );
  end component spdif;

  component data_io 
  generic
  (
    ENABLE_IDE : boolean := true
  );
  port
  (
    clk_sys   : in std_logic;
    SPI_SCK, SPI_SS2, SPI_SS4, SPI_DI : in std_logic;
    SPI_DO         : inOut std_logic;
    clkref_n       : in  std_logic := '0';
    ioctl_download : out std_logic;
    ioctl_upload   : out std_logic;
    ioctl_index    : out std_logic_vector(7 downto 0);
    ioctl_wr       : out std_logic;
    ioctl_addr     : out std_logic_vector(26 downto 0);
    ioctl_dout     : out std_logic_vector(7 downto 0);
    ioctl_din      : in  std_logic_vector(7 downto 0);

    -- IDE
    hdd_clk        : in  std_logic;
    hdd_cmd_req    : in  std_logic;
    hdd_cdda_req   : in  std_logic;
    hdd_dat_req    : in  std_logic;
    hdd_cdda_wr    : out std_logic;
    hdd_status_wr  : out std_logic;
    hdd_addr       : out std_logic_vector(2 downto 0);
    hdd_wr         : out std_logic;

    hdd_data_out   : out std_logic_vector(15 downto 0);
    hdd_data_in    : in  std_logic_vector(15 downto 0);
    hdd_data_rd    : out std_logic;
    hdd_data_wr    : out std_logic;

    -- IDE config
    hdd0_ena       : out std_logic_vector(1 downto 0);
    hdd1_ena       : out std_logic_vector(1 downto 0)
  );
  end component data_io;

  component ide
  port
  (
    clk           : in  std_logic;
    clk_en        : in  std_logic;
    reset         : in  std_logic;
    address_in    : in  std_logic_vector(2 downto 0);
    sel_secondary : in  std_logic;
    data_in       : in  std_logic_vector(15 downto 0);
    data_out      : out std_logic_vector(15 downto 0);
    data_oe       : out std_logic;
    rd            : in  std_logic;
    hwr           : in  std_logic;
    lwr           : in  std_logic;
    sel_ide       : in  std_logic;
    intreq        : out std_logic_vector(1 downto 0);
    intreq_ack    : in  std_logic_vector(1 downto 0);
    nrdy          : out std_logic;
    hdd0_ena      : in  std_logic_vector(1 downto 0);
    hdd1_ena      : in  std_logic_vector(1 downto 0);
    fifo_rd       : out std_logic;
    fifo_wr       : out std_logic;

    hdd_cmd_req   : out std_logic;
    hdd_dat_req   : out std_logic;
    hdd_status_wr : in  std_logic;
    hdd_addr      : in  std_logic_vector(2 downto 0);
    hdd_wr        : in  std_logic;
    hdd_data_out  : in  std_logic_vector(15 downto 0);
    hdd_data_in   : out std_logic_vector(15 downto 0);
    hdd_data_rd   : in  std_logic;
    hdd_data_wr   : in  std_logic
  );
  end component ide;

  -- Declare SOFTCARD (Z80) component 
  -- T80s is a Z80 compatible core with synchronous interface (VHDL nativo)
  component T80s
  generic
  (
     Mode    : integer := 0;    -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
     T2Write : integer := 1;    -- 0 => WR_n active in T3, /=0 => WR_n active in T2
     IOWait  : integer := 1     -- 0 => Single cycle I/O, 1 => Std I/O cycle
  );
  port (
    RESET_n  : in  std_logic;
    CLK      : in  std_logic;
    CEN      : in  std_logic := '1';
    WAIT_n   : in  std_logic := '1';
    INT_n    : in  std_logic := '1';
    NMI_n    : in  std_logic := '1';
    BUSRQ_n  : in  std_logic := '1';
    M1_n     : out std_logic;
    MREQ_n   : out std_logic;
    IORQ_n   : out std_logic;
    RD_n     : out std_logic;
    WR_n     : out std_logic;
    RFSH_n   : out std_logic;
    HALT_n   : out std_logic;
    BUSAK_n  : out std_logic;
    OUT0     : in  std_logic := '0';
    A        : out std_logic_vector(15 downto 0);
    DI       : in  std_logic_vector(7 downto 0);
    DO       : out std_logic_vector(7 downto 0)
  );
  end component;

  -- Floppy sound emulation component
  component floppy_sound
  port (
    clk      : in  std_logic;
    phs      : in  std_logic_vector(3 downto 0);
    motor    : in  std_logic;
    speaker  : in  std_logic;
    pwm      : out std_logic
  );
  end component;

  signal CLK_28M, CLK_14M, CLK_2M, CLK_2M_D, PHASE_ZERO, PHASE_ZERO_R, PHASE_ZERO_F : std_logic;
  signal clk_div : unsigned(1 downto 0);
  signal IO_SELECT, DEVICE_SELECT : std_logic_vector(7 downto 0);
  signal IO_STROBE : std_logic;
  signal ADDR : unsigned(15 downto 0);
  signal D, PD: unsigned(7 downto 0);
  signal DISK_DO, PSG_DO, IDE_DO, SSC_DO, MOUSE_DO : unsigned(7 downto 0);
  signal IDE_OE, SSC_OE, MOUSE_OE : std_logic;
  signal DO : std_logic_vector(15 downto 0);
  signal aux : std_logic;
  signal cpu_we : std_logic;
  signal psg_irq_n, psg_nmi_n : std_logic;
  signal mouse_irq_n : std_logic;

  signal we_ram : std_logic;
  signal VIDEO, HBL, VBL : std_logic;
  signal COLOR_LINE : std_logic;
  signal COLOR_LINE_CONTROL : std_logic;
  signal SCREEN_MODE : std_logic_vector(1 downto 0);
  signal COLOR_PALETTE : std_logic_vector(1 downto 0);
  signal GAMEPORT : std_logic_vector(7 downto 0);
  signal scandoubler_disable : std_logic;
  signal ypbpr : std_logic;
  signal no_csync : std_logic;

  signal K : unsigned(7 downto 0);
  signal read_key : std_logic;
  signal akd : std_logic;

  signal flash_clk : unsigned(22 downto 0) := (others => '0');
  signal power_on_reset : std_logic := '1';
  signal reset : std_logic;

  signal D1_ACTIVE, D2_ACTIVE : std_logic;
  signal TRACK1_RAM_BUSY : std_logic;
  signal TRACK1_RAM_ADDR : unsigned(12 downto 0);
  signal TRACK1_RAM_DI : unsigned(7 downto 0);
  signal TRACK1_RAM_DO : unsigned(7 downto 0);
  signal TRACK1_RAM_WE : std_logic;
  signal TRACK1 : unsigned(5 downto 0);
  signal TRACK2_RAM_BUSY : std_logic;
  signal TRACK2_RAM_ADDR : unsigned(12 downto 0);
  signal TRACK2_RAM_DI : unsigned(7 downto 0);
  signal TRACK2_RAM_DO : unsigned(7 downto 0);
  signal TRACK2_RAM_WE : std_logic;
  signal TRACK2 : unsigned(5 downto 0);
  signal DISK_READY : std_logic_vector(1 downto 0);
  signal disk_change : std_logic_vector(3 downto 0);
  signal disk_size : std_logic_vector(63 downto 0);
  signal disk_mount : std_logic;

  signal downl : std_logic := '0';
  signal io_index : std_logic_vector(4 downto 0);
  signal size : std_logic_vector(24 downto 0) := (others=>'0');
  signal a_ram: unsigned(15 downto 0);
  signal r : unsigned(7 downto 0);
  signal g : unsigned(7 downto 0);
  signal b : unsigned(7 downto 0);
  signal blank : std_logic;
  signal hsync : std_logic;
  signal vsync : std_logic;
  signal sd_we : std_logic;
  signal sd_oe : std_logic;
  signal sd_addr : std_logic_vector(18 downto 0);
  signal sd_di : std_logic_vector(7 downto 0);
  signal sd_do : std_logic_vector(7 downto 0);
  signal io_we : std_logic;
  signal io_addr : std_logic_vector(24 downto 0);
  signal io_do : std_logic_vector(7 downto 0);
  signal io_ram_we : std_logic;
  signal io_ram_d : std_logic_vector(7 downto 0);
  signal io_ram_addr : std_logic_vector(18 downto 0);
  signal ram_we : std_logic;
  signal ram_di : std_logic_vector(7 downto 0);
  signal ram_addr : std_logic_vector(24 downto 0);

  signal i2c_start : std_logic;
  signal i2c_read : std_logic;
  signal i2c_addr : std_logic_vector(6 downto 0);
  signal i2c_subaddr : std_logic_vector(7 downto 0);
  signal i2c_wdata : std_logic_vector(7 downto 0);
  signal i2c_rdata : std_logic_vector(7 downto 0);
  signal i2c_end : std_logic;
  signal i2c_ack : std_logic;
  
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal joy        : std_logic_vector(5 downto 0);
  signal joy0       : std_logic_vector(31 downto 0);
  signal joy1       : std_logic_vector(31 downto 0);
  signal joy_an0    : std_logic_vector(31 downto 0);
  signal joy_an1    : std_logic_vector(31 downto 0);
  signal joy_an     : std_logic_vector(15 downto 0);
  signal status     : std_logic_vector(63 downto 0);
  signal ps2Clk     : std_logic;
  signal ps2Data    : std_logic;
  signal mouse_strobe : std_logic;
  signal mouse_x      : signed(8 downto 0);
  signal mouse_y      : signed(8 downto 0);
  signal mouse_flags  : std_logic_vector(7 downto 0);

  signal st_wp      : std_logic_vector( 1 downto 0);

  signal speaker_a2  : std_logic;
  signal speaker_floppy : std_logic;
  signal psg_audio_l : unsigned(9 downto 0);
  signal psg_audio_r : unsigned(9 downto 0);
  signal audio       : unsigned(9 downto 0);

  -- signals to connect sd card emulation with io controller
  signal sd_lba:  std_logic_vector(31 downto 0);
  signal sd_rd:   std_logic_vector(3 downto 0) := (others => '0');
  signal sd_wr:   std_logic_vector(3 downto 0) := (others => '0');
  signal sd_ack:  std_logic_vector(3 downto 0);

  signal SD_LBA1:  std_logic_vector(31 downto 0);
  signal SD_LBA2:  std_logic_vector(31 downto 0);
  
  -- data from io controller to sd card emulation
  signal sd_data_in: std_logic_vector(7 downto 0);
  signal sd_data_out: std_logic_vector(7 downto 0);
  signal sd_data_out_strobe:  std_logic;
  signal sd_buff_addr: std_logic_vector(8 downto 0);

  signal SD_DATA_IN1: std_logic_vector(7 downto 0);
  signal SD_DATA_IN2: std_logic_vector(7 downto 0);

  -- data io
  signal ioctl_download : std_logic;
  signal ioctl_upload   : std_logic;
  signal ioctl_index    : std_logic_vector(7 downto 0);
  signal ioctl_wr       : std_logic;
  signal ioctl_addr     : std_logic_vector(26 downto 0);
  signal ioctl_dout     : std_logic_vector(7 downto 0);
  signal ioctl_din      : std_logic_vector(7 downto 0);

  -- mb signals
  signal mb_ena         : std_logic;

  -- IDE (CFFA) signals
  signal hdd_cmd_req   : std_logic;
  signal hdd_dat_req   : std_logic;
  signal hdd_status_wr : std_logic;
  signal hdd_addr      : std_logic_vector(2 downto 0);
  signal hdd_wr        : std_logic;
  signal hdd_data_out  : std_logic_vector(15 downto 0);
  signal hdd_data_in   : std_logic_vector(15 downto 0);
  signal hdd_data_rd   : std_logic;
  signal hdd_data_wr   : std_logic;
  signal hdd0_ena      : std_logic_vector(1 downto 0);
  signal hdd1_ena      : std_logic_vector(1 downto 0);

  signal ide_cs        : std_logic;
  signal ide_addr      : std_logic_vector(2 downto 0);
  signal ide_dout      : std_logic_vector(15 downto 0);
  signal ide_din       : std_logic_vector(15 downto 0);

  signal cffa_eeprom_we: std_logic;

  signal ssc_sw1       : std_logic_vector(6 downto 1) := "111111";
  signal ssc_sw2       : std_logic_vector(5 downto 1) := "11111";

  signal pll_locked : std_logic;
  signal sdram_dqm: std_logic_vector(1 downto 0);
  signal joyx       : std_logic;
  signal joyy       : std_logic;
  signal pdl_strobe : std_logic;
  signal open_apple : std_logic;
  signal closed_apple : std_logic;

  -- ============================================================
  -- Z80 Softcard signals
  -- Architecture adapted from system.v by Jesus Arias (a2e128 core)
  --
  -- In system.v, the 6502 and Z80 are separate instances, and a bus
  -- mux selects which CPU drives ca/cdo/we BEFORE address decoding.
  -- In the MiST core, the 6502/65C02 is inside the opaque apple2 module.
  -- We cannot stop it or inject addresses into it.
  --
  -- Strategy: The apple2 core internally multiplexes video and CPU on
  -- a_ram. We let video cycles pass through unchanged. During CPU
  -- cycles (PHASE_ZERO=1), when zsel=1 we override the SDRAM address
  -- with the Z80's translated address, override data with Z80 data,
  -- and block the 6502's writes. The Z80 accesses RAM directly
  -- without going through the apple2 MMU, which is correct for CP/M
  -- (the Softcard address translation replaces the MMU function).
  -- ============================================================
  signal z80_m1_n     : std_logic;
  signal z80_mreq_n   : std_logic;
  signal z80_iorq_n   : std_logic;
  signal z80_rd_n     : std_logic;
  signal z80_wr_n     : std_logic;
  signal z80_rfsh_n   : std_logic;
  signal z80_halt_n   : std_logic;
  signal z80_busak_n  : std_logic;
  signal z80_A        : std_logic_vector(15 downto 0);
  signal z80_DO       : std_logic_vector(7 downto 0);
  signal z80_reset_n  : std_logic;
  signal z80_wait_n   : std_logic;
  signal z80_int_n    : std_logic;
  signal z80_nmi_n    : std_logic;
  signal z80_busrq_n  : std_logic;
  signal z80_DI       : std_logic_vector(7 downto 0);
  
  -- Z80 CPU select flip-flop (toggle, as in system.v line 161)
  signal zsel         : std_logic := '0';
  signal z80_ham      : std_logic_vector(3 downto 0);
  signal z80_addr_translated : std_logic_vector(15 downto 0);
  
  -- Softcard enable from OSD
  signal softcard_ena : std_logic;
  
  -- Z80 write to memory
  signal z80_mem_we   : std_logic;

  -- Z80 2MHz clock enable generation
  -- z80_vid_cen : pulso adicional a mitad de la fase vídeo (PHASE_ZERO=0)
  -- z80_vid_cnt : contador de ciclos CLK_14M dentro de la fase vídeo
  -- z80_cen_s   : cen compuesto = PHASE_ZERO_F + z80_vid_cen (ambos gateados con zsel)
  signal z80_vid_cen  : std_logic;
  signal z80_vid_cnt  : unsigned(2 downto 0);
  signal z80_cen_s    : std_logic;
  
  -- Z80 select toggle guard (prevents bounce on CPU switch)
  signal zsel_guard   : unsigned(1 downto 0) := "00";
  
  -- SDRAM aux override for Z80 (force main RAM bank)
  signal sdram_aux    : std_logic;

  -- Disk sound enable signal
  signal disk_sound_ena : std_logic;
  
  -- Stepper phases for disk sound
  signal stepper_phases : std_logic_vector(3 downto 0);
  signal disk_motor_on  : std_logic;

  -- Slot configuration signals
  signal slot4_cfg    : std_logic_vector(1 downto 0);  -- status(28:27)
  signal slot5_cfg    : std_logic_vector(1 downto 0);  -- status(25:24)
  
  -- Mouse enable for slot 4 or slot 5
  signal mouse_slot4_ena : std_logic;
  signal mouse_slot5_ena : std_logic;
  signal mouse_ena       : std_logic;
  
  -- Mockingboard slot signals
  signal mb_slot4_ena    : std_logic;
  signal mb_slot5_ena    : std_logic;
  signal mb_io_select    : std_logic;
  
  -- Mouse I/O select signals (calculated from slot configuration)
  signal mouse_io_select    : std_logic;
  signal mouse_device_select: std_logic;

begin

  st_wp <= status(9 downto 8);
  
  -- Slot configuration from OSD
  -- status(28:27) = ORS = Slot 4: 00=Mockingboard, 01=Softcard, 10=Mouse, 11=Empty
  -- status(25:24) = OOP = Slot 5: 00=Mouse, 01=Mockingboard, 10/11=Empty
  slot4_cfg <= status(28 downto 27);
  slot5_cfg <= status(25 downto 24);
  
  -- Softcard enabled when Slot 4 = "01"
  softcard_ena <= '1' when slot4_cfg = "01" else '0';
  
  -- Mockingboard
  mb_slot4_ena <= '1' when slot4_cfg = "00" else '0';
  mb_slot5_ena <= '1' when slot5_cfg = "01" else '0';
  mb_ena <= mb_slot4_ena or mb_slot5_ena;
  mb_io_select <= IO_SELECT(4) when mb_slot4_ena = '1' else
                  IO_SELECT(5) when mb_slot5_ena = '1' else '0';
  
  -- Mouse
  mouse_slot4_ena <= '1' when slot4_cfg = "10" else '0';
  mouse_slot5_ena <= '1' when slot5_cfg = "00" else '0';
  mouse_ena <= mouse_slot4_ena or mouse_slot5_ena;
  
  -- Mouse I/O select multiplexer (depends on which slot mouse is configured)
  mouse_io_select <= IO_SELECT(4) when mouse_slot4_ena = '1' else 
                     IO_SELECT(5) when mouse_slot5_ena = '1' else '0';
  mouse_device_select <= DEVICE_SELECT(4) when mouse_slot4_ena = '1' else
                         DEVICE_SELECT(5) when mouse_slot5_ena = '1' else '0';
  
  -- Disk sound enable: status(26) active low means Yes (sound enabled)
  -- OQ maps to bit 26 (Q=26 in hex notation O is bit offset)
  -- disk_sound_ena <= not status(26);
  disk_sound_ena <= status(26);

  -- In the Apple ][, this was a 555 timer
  power_on : process(CLK_14M)
  begin
    if rising_edge(CLK_14M) then
      reset <= buttons(1) or status(7) or power_on_reset;

      if status(0) = '1' then
        power_on_reset <= '1';
        flash_clk <= (others=>'0');
      else
		  if flash_clk(22) = '1' then
          power_on_reset <= '0';
			end if;
			 
        flash_clk <= flash_clk + 1;
      end if;
    end if;
  end process;
  
  SDRAM_CLK <= CLK_28M;
  
  pll : entity work.mist_clk 
  port map (
    areset => '0',
    inclk0 => CLOCK_IN,
    c0     => CLK_28M,
    c1     => CLK_14M,
    locked => pll_locked
    );

 
  -- Paddle buttons
  -- GAMEPORT input bits:
  --  7    6    5    4    3   2   1    0
  -- pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 casette
  GAMEPORT <=  "00" & joyy & joyx & "0" & (joy(5) or closed_apple) & (joy(4) or open_apple) & AUDIO_IN;
  
  joy_an <= joy_an0(15 downto 0) when status(5)='0' else joy_an1(15 downto 0);
  joy <= joy0(5 downto 0) when status(5)='0' else joy1(5 downto 0);
  
  process(CLK_14M, pdl_strobe)
    variable cx, cy : integer range -100 to 5800 := 0;
  begin
    if rising_edge(CLK_14M) then
     CLK_2M_D <= CLK_2M;
     if CLK_2M_D = '0' and CLK_2M = '1' then
      if cx > 0 then
        cx := cx -1;
        joyx <= '1';
      else
        joyx <= '0';
      end if;
      if cy > 0 then
        cy := cy -1;
        joyy <= '1';
      else
        joyy <= '0';
      end if;
      if pdl_strobe = '1' then
        cx := 2800+(22*to_integer(signed(joy_an(15 downto 8))));
        cy := 2800+(22*to_integer(signed(joy_an(7 downto 0)))); -- max 5650
        if cx < 0 then
          cx := 0;
        elsif cx >= 5590 then
          cx := 5650;
        end if;
        if cy < 0 then
          cy := 0;
        elsif cy >= 5590 then
          cy := 5650;
        end if;
      end if;
     end if;
    end if;
  end process;

  -- screen mode and color palette
  COLOR_LINE_CONTROL <= COLOR_LINE and not (status(2) or status(3));  -- Color or B&W mode
  SCREEN_MODE <= status(3 downto 2); -- 00: Color, 01: B&W, 10:Green, 11: Amber
  COLOR_PALETTE <= status(14 downto 13);
  
  -- sdram interface
  SDRAM_CKE <= '1';
  SDRAM_DQMH <= sdram_dqm(1);
  SDRAM_DQML <= sdram_dqm(0);

  -- BUG 3 FIX: Force aux='0' when Z80 is active.
  -- The SDRAM uses 'aux' to select between main/aux RAM banks on writes.
  -- When the 6502 is frozen, 'aux' retains its last value which could be '1'
  -- (e.g. from ALTZP). The Z80 always uses main RAM, so force aux='0'.
  sdram_aux <= '0' when zsel = '1' and softcard_ena = '1' else aux;
  
  sdram_inst : sdram
    port map( sd_data => SDRAM_DQ,
              sd_addr => SDRAM_A,
              sd_dqm => sdram_dqm,
              sd_cs => SDRAM_nCS,
              sd_ba => SDRAM_BA,
              sd_we => SDRAM_nWE,
              sd_ras => SDRAM_nRAS,
              sd_cas => SDRAM_nCAS,
              clk => CLK_28M,
              clkref => CLK_2M,
              init_n => pll_locked,
              din => ram_di,
              addr => ram_addr,
              we => ram_we,
              dout => DO,
              aux => sdram_aux  -- FIX: was 'aux', now forced '0' when Z80 active
    );
  
  -- ============================================================
  -- RAM Bus Interface with Z80 Softcard bus sharing
  -- ============================================================
  -- apple2 core (apple2.vhd) line 147-148:
  --   ram_addr <= CPU_RAM_ADDR when PHASE_ZERO='1' else VIDEO_ADDRESS
  --   ram_we   <= (cpu write logic) when PHASE_ZERO='1' else '0'
  --
  -- So a_ram alternates: PHASE_ZERO=0 -> VIDEO_ADDRESS, PHASE_ZERO=1 -> CPU_RAM_ADDR
  -- The SDRAM controller (sdram.v) does ONE access per CLK_2M cycle,
  -- alternating video reads and CPU accesses on successive cycles.
  --
  -- When zsel=1 (Z80 active):
  --   CPU_FREEZE=1 stops the internal 6502/65C02 (no spurious bus activity)
  --   During PHASE_ZERO=0 (video): a_ram passes through (video works normally)
  --   During PHASE_ZERO=1 (CPU): Z80 translated address/data/we replace 6502's
  -- ============================================================
  
  -- ============================================================
  -- RAM Bus Interface with Z80 Softcard bus sharing
  -- ============================================================
  -- La SDRAM alterna accesos video (PHASE_ZERO=0) y CPU (PHASE_ZERO=1).
  -- Cuando zsel=1 (Z80 activo):
  --   PHASE_ZERO=0 (video): a_ram pasa sin cambios (video normal)
  --   PHASE_ZERO=1 (CPU):   Z80 controla dirección, dato y we
  -- FIX: Separar explícitamente los casos video y CPU en ram_addr.
  -- La condición "&& softcard_ena" es redundante si zsel ya implica
  -- softcard_ena='1', pero se mantiene por seguridad defensiva.
  -- 
  -- ram_addr[24:16]=0 -> banco principal SDRAM (no auxiliar), correcto para Z80.
  -- ============================================================
  ram_we   <= '1' when power_on_reset = '1' else
              z80_mem_we when zsel = '1' and softcard_ena = '1' and PHASE_ZERO = '1' else
              '0'        when zsel = '1' and softcard_ena = '1' and PHASE_ZERO = '0' else
              we_ram;

  ram_addr <= std_logic_vector(to_unsigned(1012, ram_addr'length)) when power_on_reset = '1' else
              "000000000" & z80_addr_translated when zsel = '1' and softcard_ena = '1' and PHASE_ZERO = '1' else
              "000000000" & std_logic_vector(a_ram);

  ram_di   <= "00000000" when power_on_reset = '1' else
              z80_DO when zsel = '1' and softcard_ena = '1' and PHASE_ZERO = '1' else
              std_logic_vector(D);

  -- ============================================================
  -- Peripheral Data Bus Multiplexer (PD)
  -- Z80 is NOT a peripheral — it drives the RAM bus directly.
  -- ============================================================
  PD <= PSG_DO when mb_io_select = '1' and mb_ena = '1' else 
        SSC_DO when status(15) = '1' and SSC_OE = '1' else
        IDE_DO when status(10) = '1' and IDE_OE = '1' else
        MOUSE_DO when mouse_ena = '1' and MOUSE_OE = '1' else
        DISK_DO;

  core : entity work.apple2 port map (
    CLK_14M        => CLK_14M,
    PALMODE        => status(4),
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    PHASE_ZERO_R   => PHASE_ZERO_R,
    PHASE_ZERO_F   => PHASE_ZERO_F,
    FLASH_CLK      => flash_clk(22),
    reset          => reset,
    cpu            => status(1),
    ADDR           => ADDR,
    ram_addr       => a_ram,
    D              => D,
    ram_do         => unsigned(DO),
    aux            => aux,
    PD             => PD,
    CPU_WE         => cpu_we,
    IRQ_N          => psg_irq_n and mouse_irq_n,
    NMI_N          => psg_nmi_n,
    ram_we         => we_ram,
    VIDEO          => VIDEO,
    COLOR_LINE     => COLOR_LINE,
    HBL            => HBL,
    VBL            => VBL,
    K              => K,
    KEYSTROBE      => read_key,
    AKD            => akd,
    AN             => open,
    GAMEPORT       => GAMEPORT,
    PDL_strobe     => pdl_strobe,
    IO_SELECT      => IO_SELECT,
    DEVICE_SELECT  => DEVICE_SELECT,
    IO_STROBE      => IO_STROBE,
    CPU_FREEZE     => zsel,
    speaker        => speaker_a2
    );

  tv : entity work.tv_controller port map (
    CLK_14M    => CLK_14M,
    VIDEO      => VIDEO,
    COLOR_LINE => COLOR_LINE_CONTROL,
    SCREEN_MODE => SCREEN_MODE,
    COLOR_PALETTE => COLOR_PALETTE,
    HBL        => HBL,
    VBL        => VBL,
    VGA_CLK    => open,
    VGA_HS     => hsync,
    VGA_VS     => vsync,
    VGA_BLANK  => blank,
    VGA_R      => r,
    VGA_G      => g,
    VGA_B      => b
    );

  keyboard : entity work.keyboard port map (
    PS2_Clk  => ps2Clk,
    PS2_Data => ps2Data,
    CLK_14M  => CLK_14M,
    reset    => reset,
    reads    => read_key,
    K        => K,
    akd      => akd,
    open_apple => open_apple,
    closed_apple => closed_apple
    );

  disk : entity work.disk_ii port map (
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => IO_SELECT(6),
    DEVICE_SELECT  => DEVICE_SELECT(6),
    RESET          => reset,
    DISK_READY     => DISK_READY,
    A              => ADDR,
    D_IN           => D,
    D_OUT          => DISK_DO,
    D1_ACTIVE      => D1_ACTIVE,
    D2_ACTIVE      => D2_ACTIVE,
    WP             => st_wp,
    -- track buffer interface for disk 1
    TRACK1         => TRACK1,
    TRACK1_ADDR    => TRACK1_RAM_ADDR,
    TRACK1_DO      => TRACK1_RAM_DO,
    TRACK1_DI      => TRACK1_RAM_DI,
    TRACK1_WE      => TRACK1_RAM_WE,
    TRACK1_BUSY    => TRACK1_RAM_BUSY,
    -- track buffer interface for disk 2
    TRACK2         => TRACK2,
    TRACK2_ADDR    => TRACK2_RAM_ADDR,
    TRACK2_DO      => TRACK2_RAM_DO,
    TRACK2_DI      => TRACK2_RAM_DI,
    TRACK2_WE      => TRACK2_RAM_WE,
    TRACK2_BUSY    => TRACK2_RAM_BUSY,
    -- floppy sound emulation
    SPEAKER_I	   => speaker_a2,
    SPEAKER_O      => speaker_floppy
    );

  -- Get stepper phases and motor status from disk controller for sound
  -- Note: These signals may need to be exposed from disk_ii module
  disk_motor_on <= D1_ACTIVE or D2_ACTIVE;

  disk_mount <= '0' when disk_size = x"0000000000000000" else '1';
  sd_lba <= SD_LBA2 when sd_rd(3) = '1' or sd_wr(3) = '1' else SD_LBA1;
  sd_data_in <= SD_DATA_IN2 when sd_ack(3) = '1' else SD_DATA_IN1;
  
  sdcard_interface1: mist_sd_card port map (
    clk          => CLK_14M,
    reset        => reset,

    ram_addr     => TRACK1_RAM_ADDR, -- in unsigned(12 downto 0);
    ram_di       => TRACK1_RAM_DI,   -- in unsigned(7 downto 0);
    ram_do       => TRACK1_RAM_DO,   -- out unsigned(7 downto 0);
    ram_we       => TRACK1_RAM_WE,

    track        => std_logic_vector(TRACK1),
    busy         => TRACK1_RAM_BUSY,
    change       => DISK_CHANGE(2),
    mount        => disk_mount,
    ready        => DISK_READY(0),
    active       => D1_ACTIVE,

    sd_buff_addr => sd_buff_addr,
    sd_buff_dout => sd_data_out,
    sd_buff_din  => SD_DATA_IN1,
    sd_buff_wr   => sd_data_out_strobe,

    sd_lba       => SD_LBA1,
    sd_rd        => sd_rd(2),
    sd_wr        => sd_wr(2),
    sd_ack       => sd_ack(2)
  );

  sdcard_interface2: mist_sd_card port map (
    clk          => CLK_14M,
    reset        => reset,

    ram_addr     => TRACK2_RAM_ADDR, -- in unsigned(12 downto 0);
    ram_di       => TRACK2_RAM_DI,   -- in unsigned(7 downto 0);
    ram_do       => TRACK2_RAM_DO,   -- out unsigned(7 downto 0);
    ram_we       => TRACK2_RAM_WE,

    track        => std_logic_vector(TRACK2),
    busy         => TRACK2_RAM_BUSY,
    change       => DISK_CHANGE(3),
    mount        => disk_mount,
    ready        => DISK_READY(1),
    active       => D2_ACTIVE,

    sd_buff_addr => sd_buff_addr,
    sd_buff_dout => sd_data_out,
    sd_buff_din  => SD_DATA_IN2,
    sd_buff_wr   => sd_data_out_strobe,

    sd_lba       => SD_LBA2,
    sd_rd        => sd_rd(3),
    sd_wr        => sd_wr(3),
    sd_ack       => sd_ack(3)
  );

  LED <= not (D1_ACTIVE or D2_ACTIVE);

  -- ============================================================
  -- Mockingboard (Slot 4 when slot4_cfg="00" or Slot 5 when slot5_cfg="01")
  -- ============================================================
  mb : work.mockingboard port map (
      CLK_14M    => CLK_14M,
      PHASE_ZERO => PHASE_ZERO,
      PHASE_ZERO_R => PHASE_ZERO_R,
      PHASE_ZERO_F => PHASE_ZERO_F,
      I_RESET_L => not reset,
      I_ENA_H   => mb_ena,

      I_ADDR    => std_logic_vector(ADDR)(7 downto 0),
      I_DATA    => std_logic_vector(D),
      unsigned(O_DATA)    => PSG_DO,
      I_RW_L    => not cpu_we,
      I_IOSEL_L => not mb_io_select,
      O_IRQ_L   => psg_irq_n,
      O_NMI_L   => psg_nmi_n,
      unsigned(O_AUDIO_L) => psg_audio_l,
      unsigned(O_AUDIO_R) => psg_audio_r
      );

  cffa_eeprom_we <= '1' when ioctl_index = x"FF" and ioctl_wr = '1' else '0';

  ide_cffa : entity work.ide_cffa port map (
    CLK_28M        => CLK_28M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => IO_SELECT(7),
    IO_STROBE      => IO_STROBE,
    DEVICE_SELECT  => DEVICE_SELECT(7),
    RESET          => reset,
    A              => ADDR,
    RNW            => not cpu_we,
    D_IN           => D,
    D_OUT          => IDE_DO,
    OE             => IDE_OE,

    IDE_CS         => ide_cs,
    IDE_ADDR       => ide_addr,
    IDE_DOUT       => ide_dout,
    IDE_DIN        => ide_din,

    SAVE_A         => unsigned(ioctl_addr(10 downto 0)),
    std_logic_vector(SAVE_Q) => ioctl_din,
    SAVE_WE        => cffa_eeprom_we,
    SAVE_D         => unsigned(ioctl_dout)
  );

  ssc_sw1 <= "00"&status(16)&status(17)&status(18)&status(19);
  ssc_sw2(5) <= not status(23); -- LF after CR
  ssc_sw2(4 downto 3) <= "00" when status(22 downto 21) = "00" else -- no parity
                         "10" when status(22 downto 21) = "01" else -- odd parity
                         "11"; -- even parity
  ssc_sw2(2) <= status(20); -- data bits
  ssc_sw2(1) <= '0'; -- 1 stop bit

  ssc : entity work.ssc port map (
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => IO_SELECT(2),
    IO_STROBE      => IO_STROBE,
    DEVICE_SELECT  => DEVICE_SELECT(2),
    RESET          => reset,
    A              => ADDR,
    RNW            => not cpu_we,
    D_IN           => D,
    D_OUT          => SSC_DO,
    OE             => SSC_OE,

    SW1            => ssc_sw1,
    SW2            => ssc_sw2,

    UART_RX        => UART_RX,
    UART_TX        => UART_TX,
    UART_CTS       => UART_CTS,
    UART_RTS       => UART_RTS,
    UART_DCD       => '0',
    UART_DSR       => '0',
    UART_DTR       => open
  );

  -- ============================================================
  -- Apple Mouse (Slot 4 when slot4_cfg="10" or Slot 5 when slot5_cfg="00")
  -- ============================================================
  mouse : entity work.applemouse port map (
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => mouse_io_select,
    IO_STROBE      => IO_STROBE,
    DEVICE_SELECT  => mouse_device_select,
    RESET          => reset,
    A              => ADDR,
    RNW            => not cpu_we,
    D_IN           => D,
    D_OUT          => MOUSE_DO,
    OE             => MOUSE_OE,
    IRQ_N          => MOUSE_IRQ_N,

    STROBE         => mouse_strobe,
    X              => mouse_x,
    Y              => mouse_y,
    BUTTON         => mouse_flags(0)
  );

  -- ============================================================
  -- Z80 Softcard Implementation (Slot 4)
  -- Adapted from system.v by Jesus Arias (a2e128 core)
  --
  -- system.v reference (key lines):
  --   zsel toggle:  if ((~cclke)&(ca[15:8]==8'hC4)&we) zsel<=~zsel
  --   clock:        clk65=cclk|zsel|ftwait  (6502 stopped when zsel=1)
  --                 clkz80=cclk|(~zsel)|ftwait (Z80 stopped when zsel=0)
  --                 cktop=(ckcnt==(zsel?4'd5:4'd11)) (Z80 runs at 2MHz)
  --   bus mux:      ca = zsel? {zham,za[11:0]} : pca
  --                 cdo = zsel? zcdo : pcdo
  --                 we = zsel? (~mreq_n)&(~wr_n) : pwe
  --   Z80 data in:  cdi_d (same data path as 6502, before register)
  --   Z80 clock:    clkz80 (async clock, gated when zsel=0)
  --
  -- MiST adaptation:
  --   - apple2 core modified: CPU_FREEZE port disables internal CPU_EN
  --     when zsel=1, stopping the 6502/65C02 (prevents soft-switch corruption)
  --   - Cannot mux ca before apple2 core -> override ram_addr at SDRAM
  --   - Z80 uses CLK_14M + cen for clean FPGA clocking
  --   - Z80 reads from SDRAM output (DO) like system.v reads from xdi8
  --   - zsel toggle detected from ADDR (6502 side) and z80_addr_translated
  --     (Z80 side), since both need to trigger on $C4xx write
  -- ============================================================
  
  -- Z80 CPU select flip-flop (TOGGLE, as in system.v line 159-161)
  -- system.v: if ((~cclke)&(ca[15:8]==8'hC4)&we) zsel<=~zsel
  --
  -- In system.v, 'ca' is combinational: ca = zsel? {zham,za[11:0]} : pca
  -- So when zsel toggles, ca immediately reflects the new CPU's address,
  -- and the toggle condition disappears naturally on the next check.
  --
  -- In the MiST core, ADDR (from apple2) and z80_A (from T80s) are REGISTERED.
  -- After zsel toggles, the newly-active CPU needs at least one PHASE_ZERO_F
  -- cycle to advance and update its address. During this time, the stale
  -- address from the previous CPU could cause a false re-trigger (bounce).
  --
  -- FIX: Use a 2-cycle guard counter. After any zsel transition, block
  -- toggle detection for 2 PHASE_ZERO_F cycles. This gives the newly-active
  -- CPU time to update its address bus.
  --
  -- Both checks now use PHASE_ZERO_F (matching system.v's ~cclke = end of
  -- CPU cycle) for consistent timing.
  z80_select_proc: process(CLK_14M, reset)
  begin
    if reset = '1' then
      zsel <= '0';
      zsel_guard <= "00";
    elsif rising_edge(CLK_14M) then
      if softcard_ena = '0' then
        zsel <= '0';
        zsel_guard <= "00";
      elsif PHASE_ZERO_F = '1' then
        if zsel_guard /= "00" then
          -- Guard active: count down, skip toggle detection
          zsel_guard <= zsel_guard - 1;
        elsif zsel = '0' then
          -- 6502 active: detect write to $C4xx (Softcard slot 4 I/O)
          if ADDR(15 downto 8) = x"C4" and cpu_we = '1' then
            zsel <= '1';
            zsel_guard <= "10";  -- 2-cycle guard
          end if;
        else
          -- Z80 active: detect write to $E4xx (Z80 → Apple $C4xx)
          if z80_addr_translated(15 downto 8) = x"C4" and z80_mem_we = '1' then
            zsel <= '0';
            zsel_guard <= "10";  -- 2-cycle guard
          end if;
        end if;
      end if;
    end if;
  end process;
  
  -- Z80 Address Translation (Microsoft Softcard memory map)
  -- Maps Z80 64KB space onto Apple II 64KB space:
  --   Z80 $0000-$AFFF -> Apple $1000-$BFFF  (RAM, offset +$1000)
  --   Z80 $B000-$BFFF -> Apple $D000-$DFFF  (Language Card bank)
  --   Z80 $C000-$CFFF -> Apple $E000-$EFFF
  --   Z80 $D000-$DFFF -> Apple $F000-$FFFF
  --   Z80 $E000-$EFFF -> Apple $C000-$CFFF  (I/O & ROM area)
  --   Z80 $F000-$FFFF -> Apple $0000-$0FFF  (zero page + stack)
  -- FIX: caso 'others' con suma +1 es correcto para $0-$A, pero hacerlo
  -- explícito para todos los casos evita ambigüedades y es más seguro.
  z80_addr_translation: process(z80_A)
  begin
    case z80_A(15 downto 12) is
      when x"0"   => z80_ham <= x"1";
      when x"1"   => z80_ham <= x"2";
      when x"2"   => z80_ham <= x"3";
      when x"3"   => z80_ham <= x"4";
      when x"4"   => z80_ham <= x"5";
      when x"5"   => z80_ham <= x"6";
      when x"6"   => z80_ham <= x"7";
      when x"7"   => z80_ham <= x"8";
      when x"8"   => z80_ham <= x"9";
      when x"9"   => z80_ham <= x"A";
      when x"A"   => z80_ham <= x"B";
      when x"B"   => z80_ham <= x"D";
      when x"C"   => z80_ham <= x"E";
      when x"D"   => z80_ham <= x"F";
      when x"E"   => z80_ham <= x"C";
      when others => z80_ham <= x"0";  -- Z80 $F000-$FFFF -> Apple $0000 (zero page)
    end case;
  end process;
  
  z80_addr_translated <= z80_ham & z80_A(11 downto 0);
  
  -- Z80 Memory Write Enable (matches system.v line 200)
  -- system.v: we = zsel? (~mreq_n)&(~wr_n) : pwe
  -- FIX: añadir rfsh_n para excluir ciclos de refresh (mreq se activa
  -- durante refresh pero NO es un acceso real a memoria).
  z80_mem_we <= '1' when z80_wr_n = '0' and z80_mreq_n = '0' and z80_rfsh_n = '1' else '0';
  
  -- ============================================================
  -- Z80 2MHz clock enable: pulso adicional a mitad de la fase vídeo
  --
  -- El Z80 original de la Softcard corría a 2MHz. En el port MiST
  -- con sólo cen=PHASE_ZERO_F el Z80 va a 1MHz (la mitad).
  --
  -- Solución: añadir un segundo cen (z80_vid_cen) a mitad de la fase
  -- vídeo (PHASE_ZERO=0), donde la SDRAM atiende vídeo y no al Z80.
  -- Así las operaciones internas del Z80 (sin acceso a SDRAM) corren
  -- a 2MHz; los accesos a memoria siguen a 1MHz (correcto, una slot
  -- de SDRAM por ciclo de bus).
  --
  -- Timing (14 ciclos de CLK_14M = 1µs de bus Apple II):
  --   Ciclo 0  : PHASE_ZERO_F → cen1 (dato SDRAM válido, Z80 captura lectura)
  --   Ciclo 4  : z80_vid_cen  → cen2 (mitad fase vídeo, Z80 avanza si no hay mreq)
  --   Ciclo 7  : PHASE_ZERO_R  → SDRAM empieza acceso CPU con z80_A estable
  --   Ciclo 13 : PHASE_ZERO_F  → cen1 del siguiente ciclo
  --
  -- wait_n en z80_vid_cen:
  --   mreq_n=0 AND rfsh_n=1 (lectura o escritura real) → wait_n='0'
  --     Lectura : SDRAM aún no disponible, espera hasta PHASE_ZERO_F
  --     Escritura: ram_we está gateado por PHASE_ZERO=1; si el Z80
  --                avanzara ahora soltaría wr_n antes de que la SDRAM
  --                escriba → escritura perdida. Debe esperar.
  --   Op interna o refresh → wait_n='1', Z80 avanza libremente
  -- ============================================================
  z80_vid_phase: process(CLK_14M)
  begin
    if rising_edge(CLK_14M) then
      z80_vid_cen <= '0';                        -- default: sin pulso
      if PHASE_ZERO_F = '1' then
        z80_vid_cnt <= (others => '0');           -- inicio de fase vídeo: reiniciar contador
      elsif PHASE_ZERO = '0' then
        if z80_vid_cnt /= "111" then
          z80_vid_cnt <= z80_vid_cnt + 1;
        end if;
        if z80_vid_cnt = "011" then              -- ciclo 4 de la fase vídeo (0-indexado)
          z80_vid_cen <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Z80 Control signals
  z80_reset_n <= not reset;

  -- wait_n: '0' (insertar wait) sólo durante z80_vid_cen con acceso real a RAM.
  -- En PHASE_ZERO_F siempre '1': SDRAM completó el acceso, dato válido.
  z80_wait_n  <= '0' when zsel = '1' and z80_vid_cen = '1'
                            and z80_mreq_n = '0' and z80_rfsh_n = '1'
                 else '1';

  -- cen compuesto: PHASE_ZERO_F (fin fase CPU, dato SDRAM válido)
  --              + z80_vid_cen  (mitad fase vídeo, ops internas libres)
  --              ambos gateados con zsel (Z80 congelado cuando no es el CPU activo)
  z80_cen_s   <= (PHASE_ZERO_F or z80_vid_cen) and zsel;

  z80_int_n   <= '1';
  z80_nmi_n   <= '1';
  z80_busrq_n <= '1';
  
  -- Z80 Data input: from SDRAM output (low byte)
  -- In system.v: Z80 receives cdi_d which comes from xdi8 (RAM data)
  -- FIX: DO(7:0) se estabiliza al FINAL de la fase CPU (PHASE_ZERO=1),
  -- no al principio. Por eso el cen del Z80 debe usar PHASE_ZERO_F
  -- (flanco bajada de PHASE_ZERO), no PHASE_ZERO_R (flanco subida).
  -- Así el Z80 captura el dato cuando ya está válido en la SDRAM.
  z80_DI <= DO(7 downto 0);
  
  -- Instantiate the Z80 CPU (T80s core - VHDL nativo, sin mixed-language)
  Z80cpu : T80s
    generic map (
      Mode    => 0,    -- Z80 estándar (timing correcto para Softcard)
      T2Write => 1,
      IOWait  => 0
    )
    port map (
      RESET_n  => z80_reset_n,
      CLK      => CLK_14M,
      CEN      => z80_cen_s,   -- 2MHz: PHASE_ZERO_F + z80_vid_cen (gateados con zsel)
      WAIT_n   => z80_wait_n,
      INT_n    => z80_int_n,
      NMI_n    => z80_nmi_n,
      BUSRQ_n  => z80_busrq_n,
      M1_n     => z80_m1_n,
      MREQ_n   => z80_mreq_n,
      IORQ_n   => z80_iorq_n,
      RD_n     => z80_rd_n,
      WR_n     => z80_wr_n,
      RFSH_n   => z80_rfsh_n,
      HALT_n   => z80_halt_n,
      BUSAK_n  => z80_busak_n,
      A        => z80_A,
      DI       => z80_DI,
      DO       => z80_DO
    );

  -- ============================================================
  -- Audio Section with Floppy Sound
  -- ============================================================

  -- ============================================================
  -- Audio mixing
  -- speaker_floppy ya está conducido por disk_ii (SPEAKER_O).
  -- FIX: audio(7) lleva siempre speaker_a2 (altavoz principal).
  --      audio(6) lleva speaker_floppy cuando sonido de disco habilitado.
  -- La lógica original silenciaba speaker_a2 con disk_sound_ena=1 (BUG).
  -- ============================================================
  audio(7) <= speaker_a2;
  audio(6) <= speaker_floppy when disk_sound_ena = '1' else '0';

  audio(5 downto 0) <= (others => '0');
  audio(9 downto 8) <= (others => '0');

  -- AUDIO_R <= std_logic_vector(psg_audio_r + audio);
  -- AUDIO_L <= std_logic_vector(psg_audio_l + audio);

  dac_l : mist.dac
    generic map(10)
    port map (
      clk_i		=> CLK_14M,
      res_n_i	=> not reset,
      -- dac_i 	=> std_logic_vector(psg_audio_l + (audio & "0000000")),
      dac_i 	=> std_logic_vector(psg_audio_l + audio),
      dac_o 	=> AUDIO_L
      );

  dac_r : mist.dac
    generic map(10)
    port map (
      clk_i		=> CLK_14M,
      res_n_i	=> not reset,
      -- dac_i 	=> std_logic_vector(psg_audio_r + (audio & "0000000")),
      dac_i 	=> std_logic_vector(psg_audio_r + audio),
      dac_o 	=> AUDIO_R
      );

  my_i2s : i2s
  port map (
    clk => CLK_28M,
    reset => '0',
    clk_rate => 28_600_000,
    sclk => I2S_BCK,
    lrclk => I2S_LRCK,
    sdata => I2S_DATA,
    -- left_chan  => '0'&std_logic_vector(psg_audio_l + (audio & "0000000"))&"00000",
    left_chan  => '0'&std_logic_vector(psg_audio_l + audio)&"00000",
    -- right_chan => '0'&std_logic_vector(psg_audio_r + (audio & "0000000"))&"00000"
    right_chan => '0'&std_logic_vector(psg_audio_r + audio)&"00000"
  );

  my_spdif : spdif
  port map (
    rst_i => '0',
    clk_i => CLK_28M,
    clk_rate_i => 28_600_000,
    spdif_o => SPDIF_O,
    -- sample_i => '0'&std_logic_vector(psg_audio_r + (audio & "0000000"))&"00000" & '0'&std_logic_vector(psg_audio_l + (audio & "0000000"))&"00000"
    sample_i => '0'&std_logic_vector(psg_audio_r + audio)&"00000" & '0'&std_logic_vector(psg_audio_l + audio)&"00000"
  );

  user_io_inst : user_io
    generic map (
      STRLEN => CONF_STR'length,
      SD_IMAGES => 4,
      FEATURES => USER_IO_FEAT
    )
    port map (
      clk_sys => CLK_14M,
      clk_sd => CLK_14M,
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,    
      SPI_MISO => SPI_DO,    
      SPI_MOSI => SPI_DI,       
      conf_str => to_slv(CONF_STR),
      status => status,   
      joystick_0 => joy0,   
      joystick_1 => joy1,
      joystick_analog_0 => joy_an0,
      joystick_analog_1 => joy_an1,
      SWITCHES => switches,
      BUTTONS => buttons,
      scandoubler_disable => scandoubler_disable,
      ypbpr => ypbpr,
      no_csync => no_csync,

      i2c_start => i2c_start,
      i2c_read => i2c_read,
      i2c_addr => i2c_addr,
      i2c_subaddr => i2c_subaddr,
      i2c_dout => i2c_wdata,
      i2c_din => i2c_rdata,
      i2c_end => i2c_end,
      i2c_ack => i2c_ack,

      -- connection to io controller
      sd_lba  => sd_lba,
      sd_rd   => sd_rd,
      sd_wr   => sd_wr,
      sd_ack_x => sd_ack,
      sd_ack_conf => open,
      sd_sdhc => '1',
      sd_conf => '0',
      sd_dout => sd_data_out,
      sd_dout_strobe => sd_data_out_strobe,
      sd_din => sd_data_in,
      sd_buff_addr => sd_buff_addr,
      img_mounted => disk_change,
      img_size => disk_size,
      ps2_kbd_clk => ps2Clk,
      ps2_kbd_data => ps2Data,
      mouse_strobe => mouse_strobe,
      mouse_x => mouse_x,
      mouse_y => mouse_y,
      mouse_flags => mouse_flags
    );

  data_io_inst: data_io
    port map (
      clk_sys => CLK_14M,
      SPI_SCK => SPI_SCK,
      SPI_SS2 => SPI_SS2,
      SPI_SS4 => SPI_SS4,
      SPI_DI => SPI_DI,
      SPI_DO => SPI_DO,

      clkref_n => '0',

      ioctl_download => ioctl_download,
      ioctl_upload   => ioctl_upload,
      ioctl_index    => ioctl_index,
      ioctl_wr       => ioctl_wr,
      ioctl_addr     => ioctl_addr,
      ioctl_dout     => ioctl_dout,
      ioctl_din      => ioctl_din,

      hdd_clk        => CLK_28M,
      hdd_cmd_req    => hdd_cmd_req,
      hdd_cdda_req   => '0',
      hdd_dat_req    => hdd_dat_req,
      hdd_cdda_wr    => open,
      hdd_status_wr  => hdd_status_wr,
      hdd_addr       => hdd_addr,
      hdd_wr         => hdd_wr,

      hdd_data_out   => hdd_data_out,
      hdd_data_in    => hdd_data_in,
      hdd_data_rd    => hdd_data_rd,
      hdd_data_wr    => hdd_data_wr,

      -- IDE config
      hdd0_ena       => hdd0_ena,
      hdd1_ena       => hdd1_ena
    );

  ide_inst: ide port map (
    clk           => CLK_28M,
    clk_en        => '1',
    reset         => reset,
    address_in    => ide_addr,
    sel_secondary => '0',
    data_in       => ide_din,
    data_out      => ide_dout,
    data_oe       => open,
    rd            => not cpu_we,
    hwr           => cpu_we,
    lwr           => cpu_we,
    sel_ide       => ide_cs,
    intreq        => open,
    intreq_ack    => "00",
    nrdy          => open,
    hdd0_ena      => hdd0_ena,
    hdd1_ena      => hdd1_ena,
    fifo_rd       => open,
    fifo_wr       => open,

    hdd_cmd_req   => hdd_cmd_req,
    hdd_dat_req   => hdd_dat_req,
    hdd_status_wr => hdd_status_wr,
    hdd_addr      => hdd_addr,
    hdd_wr        => hdd_wr,
    hdd_data_out  => hdd_data_out,
    hdd_data_in   => hdd_data_in,
    hdd_data_rd   => hdd_data_rd,
    hdd_data_wr   => hdd_data_wr
  );

  vga_video : mist_video
    generic map(
      COLOR_DEPTH => 8,
      SD_HCNT_WIDTH => 10,
      OUT_COLOR_DEPTH => VGA_BITS,
      BIG_OSD => BIG_OSD
    )
    port map (
      clk_sys => CLK_28M,
      scanlines   => status(12 downto 11),
      ce_divider => "001",
      scandoubler_disable => scandoubler_disable,
      ypbpr => ypbpr,
      no_csync => no_csync,
      rotate => "00",

      SPI_DI => SPI_DI,
      SPI_SCK => SPI_SCK,
      SPI_SS3 => SPI_SS3,

      R => std_logic_vector(r),
      G => std_logic_vector(g),
      B => std_logic_vector(b),
      HSync => hsync,
      VSync => vsync,
      VGA_HS => VGA_HS,
      VGA_VS => VGA_VS,
      VGA_R  => VGA_R,
      VGA_G  => VGA_G,
      VGA_B  => VGA_B
    );

  hdmi_block : if HDMI generate
    i2c_master_d : i2c_master
    generic map (
      CLK_Freq => 28000000
    )
    port map (
      CLK => CLK_28M,
      I2C_START => i2c_start,
      I2C_READ => i2c_read,
      I2C_ADDR => i2c_addr,
      I2C_SUBADDR => i2c_subaddr,
      I2C_WDATA => i2c_wdata,
      I2C_RDATA => i2c_rdata,
      I2C_END => i2c_end,
      I2C_ACK => i2c_ack,
      I2C_SCL => HDMI_SCL,
      I2C_SDA => HDMI_SDA
  );

  hdmi_video : mist_video
  generic map (
    SD_HCNT_WIDTH => 10,
    COLOR_DEPTH => 8,
    OSD_COLOR => "011",
    USE_BLANKS => true,
    OUT_COLOR_DEPTH => 8,
    BIG_OSD => BIG_OSD,
    VIDEO_CLEANER => true
  )
  port map (
    clk_sys => CLK_28M,
    scanlines   => status(12 downto 11),
    ce_divider => "001",
    scandoubler_disable => '0',
    ypbpr => '0',
    no_csync => '1',
    rotate => "00",

    SPI_DI => SPI_DI,
    SPI_SCK => SPI_SCK,
    SPI_SS3 => SPI_SS3,

    R => std_logic_vector(r),
    G => std_logic_vector(g),
    B => std_logic_vector(b),
    HBlank => blank,
    VBlank => not vsync,
    HSync => hsync,
    VSync => vsync,
    VGA_HS => HDMI_HS,
    VGA_VS => HDMI_VS,
    VGA_R  => HDMI_R,
    VGA_G  => HDMI_G,
    VGA_B  => HDMI_B,
    VGA_DE => HDMI_DE
  );

  HDMI_PCLK <= CLK_28M;
end generate;

end datapath;
