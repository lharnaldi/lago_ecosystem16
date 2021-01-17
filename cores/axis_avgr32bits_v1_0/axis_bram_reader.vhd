library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_bram_reader is
  generic (
            BRAM_DEPTH       : natural := 1024;
            BRAM_AWIDTH      : natural := 10;
            AXIS_TDATA_WIDTH : natural := 32
          );
  port (
         -- System signals
         aclk             : in std_logic;
         aresetn          : in std_logic;

         cfg_data_o       : out std_logic_vector(BRAM_AWIDTH-1 downto 0);
         cfg_data         : in std_logic_vector(BRAM_AWIDTH-1 downto 0);
         sts_data         : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         done             : in std_logic;
         send             : in std_logic;
         restart_o        : out std_logic;

         -- Master side
         m_axis_tready    : in std_logic;
         m_axis_tdata     : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         m_axis_tvalid    : out std_logic;
         m_axis_tlast     : out std_logic;
         m_axis_tkeep     : out std_logic_vector(4-1 downto 0);

         -- BRAM port
         bram_porta_clk   : out std_logic;
         --bram_porta_rst   : out std_logic;
         bram_porta_addr  : out std_logic_vector(BRAM_AWIDTH-1 downto 0);
         bram_porta_rddata: in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
       );
end axis_bram_reader;

architecture rtl of axis_bram_reader is

  type state_t is (
  ST_IDLE,
  ST_SEND_DATA,
  ST_DLY1
);
signal state_reg, state_next      : state_t;

signal addr_reg, addr_next     : unsigned(BRAM_AWIDTH-1 downto 0);
signal tlast_s                 : std_logic;
signal tvalid_reg, tvalid_next : std_logic;
signal restart_s               : std_logic;
signal tkeep_reg, tkeep_next   : std_logic_vector(4-1 downto 0);
signal cfg_data_reg, cfg_data_next : std_logic_vector(BRAM_AWIDTH-1 downto 0);

begin

  cfg_data_o <= cfg_data_reg;
  cfg_data_next <= cfg_data;
  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        state_reg  <= ST_IDLE;
        addr_reg   <= (others => '0');
        tvalid_reg <= '0';
        tkeep_reg  <= (others => '0');
        cfg_data_reg <= (others => '0');
      else 
        state_reg  <= state_next;
        addr_reg   <= addr_next;
        tvalid_reg <= tvalid_next;
        tkeep_reg  <= tkeep_next;
        cfg_data_reg  <= cfg_data_next;
      end if;
    end if;
  end process;
  tkeep_next <= (others => '1');

  --Next state logic
  process(state_reg, addr_reg, done, send, m_axis_tready, cfg_data_reg)
  begin
    state_next    <= state_reg;
    addr_next     <= addr_reg;
    tvalid_next   <= tvalid_reg;
    tlast_s       <= '0';
    restart_s     <= '0';

    case state_reg is
      when ST_IDLE => 
        addr_next     <= (others => '0');
        tvalid_next   <= '0';
        if (done = '1') and (send = '1') then
          --addr_next <= addr_reg + 1;
          tvalid_next <= '1';
          state_next  <= ST_SEND_DATA;
        else
          state_next  <= ST_IDLE;
        end if;

      when ST_SEND_DATA =>
        --tvalid_next <= '1';
        if m_axis_tready = '1' then
          addr_next <= addr_reg + 1;
          if (addr_reg = unsigned(cfg_data_reg)-1) then
            addr_next <= (others => '0');
            state_next <= ST_DLY1;
            tlast_s <= '1';
            tvalid_next <= '0';
          else
            state_next <= ST_SEND_DATA;
          end if;
        else 
          state_next <= ST_SEND_DATA;
        end if;

      when ST_DLY1 =>
        restart_s <= '1';
        state_next <= ST_IDLE;

    end case;
  end process;

  sts_data <= std_logic_vector(resize(unsigned(addr_reg),sts_data'length));

  m_axis_tdata  <= bram_porta_rddata;
  m_axis_tvalid <= tvalid_reg;
  m_axis_tlast  <= tlast_s;
  --m_axis_tkeep  <= (others => '0') when state_reg = ST_IDLE else (others => '1');
  m_axis_tkeep  <= tkeep_reg;

  bram_porta_clk <= aclk;
  --bram_porta_rst <= aresetn;
  bram_porta_addr <= std_logic_vector(addr_reg);
  restart_o <= restart_s; 

end rtl;
