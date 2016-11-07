library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity axis_ram_writer is
  generic (
  ADDR_WIDTH : integer := 20;
  AXI_ID_WIDTH : integer := 6;
  AXI_ADDR_WIDTH : integer := 32;
  AXI_DATA_WIDTH : integer := 64;
  AXI_TDATA_WIDTH : integer := 64
  );
  port (
  -- System signals
  aclk           : in std_logic;
  aresetn        : in std_logic;
  
  -- Configuration bits
  cfg_data       : in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
  sts_data       : out std_logic_vector(ADDR_WIDTH-1 downto 0);

  -- Master side
  m_axi_awid : out std_logic_vector(AXI_ID_WIDTH-1 downto 0);    -- AXI master: Write address ID
  m_axi_awaddr: out std_logic_vector(AXI_ADDR_WIDTH-1 downto 0); -- AXI master: Write address
  m_axi_awlen : out std_logic_vector(3 downto 0);                -- AXI master: Write burst length
  m_axi_awsize: out std_logic_vector(2 downto 0);                -- AXI master: Write burst size
  m_axi_awburst: out std_logic_vector(1 downto 0);               -- AXI master: Write burst type
  m_axi_awcache: out std_logic_vector(3 downto 0);               -- AXI master: Write memory type
  m_axi_awvalid: out std_logic;                                  -- AXI master: Write address valid
  m_axi_awready: in std_logic;                                   -- AXI master: Write address ready
  m_axi_wid: out std_logic_vector(AXI_ID_WIDTH-1 downto 0);      -- AXI master: Write data ID
  m_axi_wdata: out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);  -- AXI master: Write data
  m_axi_wstrb: out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);  -- AXI master: Write strobes
  m_axi_wlast: out std_logic;                                    -- AXI master: Write last
  m_axi_wvalid: out std_logic;                                   -- AXI master: Write valid
  m_axi_wready: in std_logic;                                    -- AXI master: Write ready
  m_axi_bvalid: in std_logic;                                    -- AXI master: Write response valid
  m_axi_bready: out std_logic;                                   -- AXI master: Write response ready

  -- Slave side
  s_axis_tready: out std_logic;
  s_axis_tdata: in std_logic_vector(AXI_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid: in std_logic
);
end axis_ram_writer;

architecture rtl of axis_ram_writer is

  function clogb2 (value: natural) return integer is
  variable temp    : integer := value;
	variable ret_val : integer := 0;
	begin
	while temp > 1 loop
	  ret_val := ret_val + 1;
	  temp    := temp / 2;
	end loop;

	return ret_val;
  end function;

  constant ADDR_SIZE : integer := clogb2(AXI_DATA_WIDTH/8 - 1);

  signal int_awvalid_reg, int_awvalid_next: std_logic;
  signal int_wvalid_reg, int_wvalid_next: std_logic;
  signal int_addr_reg, int_addr_next: unsigned(ADDR_WIDTH-1 downto 0);
  signal int_wid_reg, int_wid_next: unsigned(AXI_ID_WIDTH-1 downto 0);
  
  signal int_full_wire, int_empty_wire, int_rden_wire: std_logic;
  signal int_wlast_wire, int_tready_wire: std_logic;
  signal int_wdata_wire: std_logic_vector(71 downto 0);
  
  signal tmp_s1, tmp_s2: std_logic;
  signal tmp_s3: std_logic_vector(71 downto 0);

begin
	
  int_tready_wire <= not(int_full_wire);
	int_wlast_wire <= '1' when (int_addr_reg(3 downto 0) = "1111") else '0';
  int_rden_wire <= m_axi_wready and int_wvalid_reg;
	tmp_s1 <= not(aresetn);
	tmp_s2 <= int_tready_wire and s_axis_tvalid;
	tmp_s3 <= (tmp_s3'length downto AXI_TDATA_WIDTH => '0') & s_axis_tdata;

  FIFO36E1_inst: FIFO36E1 
	generic map(
    FIRST_WORD_FALL_THROUGH => TRUE,
    ALMOST_EMPTY_OFFSET => X"1FFF",
    DATA_WIDTH => 72,
    FIFO_MODE => "FIFO36_72"
  ) 
	port map (
    FULL => int_full_wire,
    ALMOSTEMPTY => int_empty_wire,
    RST => tmp_s1,
    WRCLK => aclk,
    WREN => tmp_s2,
    DI => tmp_s3,
    RDCLK => aclk,
    RDEN => int_rden_wire,
    DO => int_wdata_wire,
    DIP => (others => '0')
  );

	process(aclk, aresetn)
  begin
  if (aresetn = '0') then
    int_awvalid_reg <= '0';
    int_wvalid_reg <= '0';
    int_addr_reg <= (others => '0');
    int_wid_reg <= (others => '0');
        elsif (rising_edge(aclk)) then
    int_awvalid_reg <= int_awvalid_next;
    int_wvalid_reg <= int_wvalid_next;
    int_addr_reg <= int_addr_next;
    int_wid_reg <= int_wid_next;
  end if;
  end process;

  int_awvalid_next <= '1' when ((int_empty_wire = '0') and (int_awvalid_reg = '0') and (int_wvalid_reg = '0')) or 
                      ((m_axi_wready = '1') and (int_wlast_wire = '1') and (int_empty_wire = '0')) else 
	              '0' when (m_axi_awready = '1') and (int_awvalid_reg = '1') else
	              int_awvalid_reg;

  int_wvalid_next <= '1' when (int_empty_wire = '0') and (int_awvalid_reg = '0') and (int_wvalid_reg = '0') else 
                     '0' when (m_axi_wready = '1') and (int_wlast_wire = '1') and (int_empty_wire = '1') else
		      int_wvalid_reg;

  int_addr_next <= int_addr_reg + 1 when (int_rden_wire = '1') else
	                 int_addr_reg;

  int_wid_next <= int_wid_reg + 1 when (m_axi_wready = '1') and (int_wlast_wire = '1') else
									int_wid_reg;

  sts_data <= std_logic_vector(int_addr_reg);

  m_axi_awid <= std_logic_vector(int_wid_reg);
  m_axi_awaddr <= std_logic_vector(unsigned(cfg_data) + (int_addr_reg & (AXI_ADDR_WIDTH-int_addr_reg'length downto 0 => '0')));
  m_axi_awlen <= std_logic_vector(to_unsigned(15, m_axi_awlen'length));
  m_axi_awsize <= std_logic_vector(to_unsigned(ADDR_SIZE, m_axi_awsize'length));
  m_axi_awburst <= "01";
  m_axi_awcache <= "0011";
  m_axi_awvalid <= int_awvalid_reg;
  m_axi_wid <= std_logic_vector(int_wid_reg);
  m_axi_wdata <= int_wdata_wire(AXI_DATA_WIDTH-1 downto 0);
  m_axi_wstrb <= ((AXI_DATA_WIDTH/8-1) downto 0 => '1');
  m_axi_wlast <= int_wlast_wire;
  m_axi_wvalid <= int_wvalid_reg;
  m_axi_bready <= '1';

  s_axis_tready <= int_tready_wire;

end rtl;
