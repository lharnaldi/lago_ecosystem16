library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_reader is
  generic (
            MEM_DEPTH   : natural := 1024;
            MEM_AWIDTH  : natural := 10;
            DRATIO      : natural := 8;
            AXIS_DWIDTH : natural := 32
          );
  port (
         -- System signals
         aclk           : in std_logic;
         aresetn        : in std_logic;

         cfg_data_i     : in std_logic_vector(16-1 downto 0);
         --sts_data_o     : out std_logic_vector(AXIS_DWIDTH-1 downto 0);
         done_i         : in std_logic;
         send_i         : in std_logic;
         restart_o      : out std_logic;

         -- Master side
         m_axis_tready  : in std_logic;
         m_axis_tdata   : out std_logic_vector(AXIS_DWIDTH-1 downto 0);
         m_axis_tvalid  : out std_logic;
         m_axis_tlast   : out std_logic;
         m_axis_tkeep   : out std_logic_vector(4-1 downto 0);

         -- BRAM port
         bram_clk       : out std_logic;
         bram_rst       : out std_logic;
         bram_en        : out std_logic;
         bram_addr      : out std_logic_vector(MEM_AWIDTH-1 downto 0);
         bram_rddata    : in std_logic_vector((DRATIO*AXIS_DWIDTH)-1 downto 0)
       );
end bram_reader;

architecture rtl of bram_reader is

  type state_t is (
  ST_IDLE,
  ST_EN_BRAM,
  ST_LOAD_DATA,
  ST_SEND_DATA,
  --ST_TLAST,
  ST_FINISH
);
signal state_reg, state_next   : state_t;

signal addr_reg, addr_next     : unsigned(MEM_AWIDTH-1 downto 0);
signal tlast_s, rst_s, en_s    : std_logic;
signal tvalid_s                : std_logic;
signal restart_s               : std_logic;
signal tkeep_s                 : std_logic_vector(4-1 downto 0);
--signal bram_st_mon             : std_logic_vector(4-1 downto 0);
signal load_s                  : std_logic;
signal cntr_reg, cntr_next     : unsigned(DRATIO-1 downto 0); --4 should be enough

begin

  sh_reg_i : entity work.shift_reg_vect
  generic map(
               DWIDTH => 32,
               DRATIO => 8
             )
  port map(
            aclk   => aclk,
            --serin  => (others => '0'),
            load   => load_s,
            parin  => bram_rddata,
            serout => m_axis_tdata
          );

  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        state_reg  <= ST_IDLE;
        addr_reg   <= (others => '0');
        cntr_reg   <= (others => '0');
      else 
        state_reg  <= state_next;
        addr_reg   <= addr_next;
        cntr_reg   <= cntr_next;
      end if;
    end if;
  end process;

  --Next state logic
  process(state_reg, addr_reg, cntr_reg, done_i, send_i, m_axis_tready,
    cfg_data_i)
  begin
    state_next   <= state_reg;
    addr_next    <= addr_reg;
    cntr_next    <= cntr_reg;
    tvalid_s     <= '0';
    tlast_s      <= '0';
    restart_s    <= '0';
    en_s         <= '0';
    rst_s        <= '0';
    load_s       <= '0';
    tkeep_s      <= (others => '0');

    case state_reg is
      when ST_IDLE => 
        --bram_st_mon <= "0000"; --state mon
        rst_s       <= '1';
        addr_next  <= (others => '0');
        if (done_i = '1') and (send_i = '1') then
          state_next  <= ST_EN_BRAM;
        else
          state_next  <= ST_IDLE;
        end if;

      when ST_EN_BRAM =>
        --bram_st_mon <= "0001"; --state mon
        if m_axis_tready = '1' then
          en_s <= '1';
          addr_next <= addr_reg + 1;
          state_next  <= ST_LOAD_DATA;
        else
          state_next <= ST_EN_BRAM;
        end if;

      when ST_LOAD_DATA =>
        en_s <= '1';
        load_s <= '1';
        state_next  <= ST_SEND_DATA;

      when ST_SEND_DATA =>
        --bram_st_mon <= "0010"; --state mon
        tvalid_s <= '1';
        tkeep_s  <= (others => '1');
        if m_axis_tready = '1' then
          cntr_next <= cntr_reg + 1;
          if (cntr_reg = DRATIO-1) then
            addr_next <= addr_reg + 1;
            if (addr_reg = unsigned(cfg_data_i)) then
              addr_next <= (others => '0');
              tlast_s <= '1';
              cntr_next <= (others => '0');
              state_next <= ST_FINISH;
            else
              en_s <= '1';
              load_s <= '1';
              cntr_next <= (others => '0');
              state_next <= ST_SEND_DATA;
            end if;
          else 
            state_next <= ST_SEND_DATA;
          end if;
        else 
          state_next <= ST_SEND_DATA;
        end if;

    --when ST_TLAST =>
    --  bram_st_mon <= "0011";
    --  tvalid_s <= '1';
    --  tlast_s <= '1';
    --  state_next <= ST_FINISH;

      when ST_FINISH =>
        --bram_st_mon <= "0011"; --state mon
        restart_s <= '1';
        state_next <= ST_IDLE;

    end case;
  end process;

  --sts_data_o <= std_logic_vector(resize(addr_reg,AXIS_DWIDTH));

--m_axis_tdata  <= bram_rddata;
  m_axis_tvalid <= tvalid_s;
  m_axis_tlast  <= tlast_s;
  m_axis_tkeep  <= tkeep_s;

  bram_clk <= aclk;
  bram_rst <= rst_s;
  bram_en  <= en_s;
  bram_addr <= std_logic_vector(addr_reg);
  restart_o <= restart_s; 

end rtl;
