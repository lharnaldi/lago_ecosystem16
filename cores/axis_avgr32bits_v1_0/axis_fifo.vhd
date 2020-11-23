library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_fifo is
  generic(
           AXIS_TDATA_WIDTH : natural := 32;
           FIFO_DEPTH       : natural := 16
         --           AWIDTH           : natural := 2
         );
  port(
        -- Slave data interface
        s_axis_aclk       : in std_logic;
        s_axis_aresetn    : in std_logic;
        s_axis_tready     : out std_logic;
        s_axis_tvalid     : in std_logic;
        s_axis_tdata      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

        -- Master data interface
        m_axis_aclk       : in std_logic;
        m_axis_aresetn    : in std_logic;
        m_axis_tready     : in std_logic;
        m_axis_tvalid     : out std_logic;
        --m_axis_tlast      : out std_logic;
        m_axis_tdata      : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
      );
end axis_fifo;

architecture rtl of axis_fifo is
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

  constant AWIDTH : natural := log2c(FIFO_DEPTH);

  signal s_tready_reg, s_tready_next : std_logic;
  signal m_tvalid_reg, m_tvalid_next : std_logic;
  signal we_s, rd_s, full_s, empty_s : std_logic;
  signal w_addr_s, r_addr_s          : std_logic_vector(AWIDTH-1 downto 0);

begin

  s_axis_tready <= s_tready_reg;

  --slave port registers
  process(s_axis_aclk)
  begin
    if rising_edge(s_axis_aclk) then
      if (s_axis_aresetn = '0') then
        s_tready_reg <= '0';
      else
        s_tready_reg <= s_tready_next;
      end if;
    end if;
  end process;
  --next state logic
  s_tready_next <= '1' when (full_s = '0') else '0'; 
  we_s          <= '1' when (full_s = '0') and (s_axis_tvalid = '1') else '0';

  m_axis_tvalid <= m_tvalid_reg;
  --master port registers
  process(m_axis_aclk)
  begin
    if rising_edge(m_axis_aclk) then
      if (m_axis_aresetn = '0') then
        m_tvalid_reg <= '0';
      else
        m_tvalid_reg <= m_tvalid_next;
      end if;
    end if;
  end process;
  --next state logic
  m_tvalid_next <= '1' when (empty_s = '0') else '0';
  rd_s          <= '1' when (empty_s = '0') and (m_axis_tready = '1') else '0';

  --port a is wr port (slave)
  --port b is rd port (master)
  dp_ram_i: entity work.tdp_bram 
  generic map(
               AWIDTH       => AWIDTH,
               DWIDTH       => AXIS_TDATA_WIDTH
             )
  port map(
            clka    => s_axis_aclk,
            clkb    => m_axis_aclk,
            ena     => '1',
            enb     => '1',
            wea     => we_s,
            web     => '0',
            addra   => w_addr_s,
            addrb   => r_addr_s,
            dia     => s_axis_tdata,
            dib     => (others => '0'),
            doa     => open,
            dob     => m_axis_tdata
          );

  fifo_ctrl_i: entity work.fifo_async_ctrl
  generic map(
               --DEPTH => FIFO_DEPTH
               DEPTH => AWIDTH
             )
  port map(
            clkw   => s_axis_aclk,
            resetw => s_axis_aresetn,
            wr     => we_s,
            full   => full_s,
            w_addr => w_addr_s,
            clkr   => m_axis_aclk,
            resetr => m_axis_aresetn,
            rd     => rd_s,
            empty  => empty_s,
            r_addr => r_addr_s
          );

end rtl;
