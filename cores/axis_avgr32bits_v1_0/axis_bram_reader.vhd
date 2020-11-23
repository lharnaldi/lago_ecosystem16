library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_bram_reader is
  generic (
            BRAM_DEPTH        : natural := 1024;
            BRAM_DATA_WIDTH   : natural := 32;
            AXIS_TDATA_WIDTH  : natural := 32
          );
  port (
         -- System signals
         aclk             : in std_logic;
         aresetn          : in std_logic;

         cfg_data         : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         sts_data         : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         done             : in std_logic;
         send             : in std_logic;
         restart_o        : out std_logic;

         -- Master side
         m_axis_tready    : in std_logic;
         m_axis_tdata     : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         m_axis_tvalid    : out std_logic;
         m_axis_tlast     : out std_logic;

         -- BRAM port
         bram_porta_clk   : out std_logic;
         --bram_porta_rst   : out std_logic;
         bram_porta_addr  : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         bram_porta_rddata: in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
       );
end axis_bram_reader;

architecture rtl of axis_bram_reader is

  function log2c(n: integer) return integer is
    variable m, p: integer;
  begin
    m := 0;
    p := 1;
    while p < n loop
      m := m + 1;
      p := p * 2;
    end loop;
    return m;
  end log2c;

  constant BRAM_ADDR_WIDTH : integer := log2c(BRAM_DEPTH);

  type state_t is (
  ST_IDLE,
  ST_DLY1,
  --ST_WAIT_READY,
  ST_SEND_DATA
);
signal state_reg, state_next      : state_t;

signal addr_reg, addr_next     : unsigned(BRAM_ADDR_WIDTH-1 downto 0);
signal tvalid_s, tlast_s       : std_logic;
signal tvalid_reg, tvalid_next : std_logic;
signal tlast_reg, tlast_next : std_logic;

begin

  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        state_reg  <= ST_IDLE;
        addr_reg   <= (others => '1');
        tvalid_reg <= '0';
        tlast_reg  <= '0';
      else 
        state_reg  <= state_next;
        addr_reg   <= addr_next;
        tvalid_reg <= tvalid_next;
        tlast_reg  <= tlast_next;
      end if;
    end if;
  end process;

  --Next state logic
  process(state_reg, addr_reg, done, send, m_axis_tready)
  begin
    state_next    <= state_reg;
    addr_next     <= addr_reg;
    --tvalid_s      <= '0';
    tvalid_next   <= '0';
    tlast_next    <= '0';
    --tlast_s       <= '0';

    case state_reg is
      when ST_IDLE => 
        if (done = '1') and (send = '1') then
          addr_next <= addr_reg + 1;
          state_next  <= ST_DLY1;
        else
          state_next  <= ST_IDLE;
        end if;

      when ST_DLY1 =>
        addr_next <= addr_reg + 1;
        state_next <= ST_SEND_DATA;
        --state_next <= ST_WAIT_READY;

      --when ST_WAIT_READY =>  
      --  if m_axis_tready = '1' then
      --    state_next <= ST_SEND_DATA;
      --    addr_next <= addr_reg + 1;
      --  end if;

      when ST_SEND_DATA =>
        --tvalid_s <= '1';
        tvalid_next <= '1';
        if m_axis_tready = '1' then
          addr_next <= addr_reg + 1;
          if (addr_reg = unsigned(cfg_data)) then
            addr_next <= (others => '1');
            state_next <= ST_IDLE;
            --tlast_s <= '1';
            tlast_next <= '1';
          else
            state_next <= ST_SEND_DATA;
          end if;
        else 
          state_next <= ST_SEND_DATA;
        end if;
    end case;
  end process;

  sts_data <= std_logic_vector(resize(addr_reg,sts_data'length));

  m_axis_tdata  <= bram_porta_rddata;
  --m_axis_tvalid <= tvalid_s;
  m_axis_tvalid <= tvalid_reg;
  --m_axis_tlast  <= tlast_s;
  m_axis_tlast  <= tlast_reg;

  bram_porta_clk <= aclk;
  --bram_porta_rst <= aresetn;
  bram_porta_addr <= std_logic_vector(resize(addr_next,bram_porta_addr'length));
  restart_o <= tlast_reg;

end rtl;
