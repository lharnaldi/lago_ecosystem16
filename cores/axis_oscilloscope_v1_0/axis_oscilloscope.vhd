library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity axis_oscilloscope is
  generic (
  AXIS_TDATA_WIDTH : natural := 32;
  CNTR_WIDTH : natural := 32
);
port (
  -- System signals
  aclk           : in std_logic;
  aresetn        : in std_logic;

  run_flag        : in std_logic;
  trg_flag        : in std_logic;

  pre_data        : in std_logic_vector(CNTR_WIDTH-1 downto 0);
  tot_data        : in std_logic_vector(CNTR_WIDTH-1 downto 0);

  sts_data        : out std_logic_vector(CNTR_WIDTH downto 0);

  -- Slave side
  s_axis_tready   : out std_logic;
  s_axis_tdata    : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid   : in std_logic;

  -- Master side
  m_axis_tdata    : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tvalid   : out std_logic
);
end axis_oscilloscope;

architecture rtl of axis_oscilloscope is

  signal int_addr_reg, int_addr_next: std_logic_vector(CNTR_WIDTH-1 downto 0);
  signal int_cntr_reg, int_cntr_next: unsigned(CNTR_WIDTH-1 downto 0);
  signal int_case_reg, int_case_next: std_logic_vector(1 downto 0);
  signal int_enbl_reg, int_enbl_next: std_logic;

begin

  process(aclk)
  begin
    if (rising_edge(aclk)) then
    if (aresetn = '0') then
      int_addr_reg <= (others => '0');
      int_cntr_reg <= (others => '0');
      int_case_reg <= (others => '0');
      int_enbl_reg <= '0';
    else
      int_addr_reg <= int_addr_next;
      int_cntr_reg <= int_cntr_next;
      int_case_reg <= int_case_next;
      int_enbl_reg <= int_enbl_next;
    end if;
    end if;
  end process;

  --Next-State logic
  process(int_case_reg, int_addr_reg, int_cntr_reg, int_enbl_reg,
          run_flag, s_axis_tvalid, pre_data, trg_flag, tot_data)
  begin
    int_addr_next <= int_addr_reg;
    int_cntr_next <= int_cntr_reg;
    int_case_next <= int_case_reg;
    int_enbl_next <= int_enbl_reg;

    case int_case_reg is
      --idle
      when "00" =>
        if (run_flag = '1') then
          int_addr_next <= (others => '0');
          int_cntr_next <= (others => '0');
          int_enbl_next <= '1';
          int_case_next <= "01";
        end if;

      -- pre-trigger recording
      when "01" =>
        if (s_axis_tvalid = '1') then
          int_cntr_next <= int_cntr_reg + 1;
          if(int_cntr_reg = unsigned(pre_data)) then
            int_case_next <= "10";
          end if;
        end if;

      -- pre-trigger recording
      when "10" =>
        if (s_axis_tvalid = '1') then
          int_cntr_next <= int_cntr_reg + 1;
          if (trg_flag = '1') then
            int_addr_next <= std_logic_vector(int_cntr_reg);
            int_cntr_next <= unsigned(pre_data) + int_cntr_reg(5 downto 0);
            int_case_next <= "11";
          end if;
        end if;

      -- post-trigger recording
      when "11" =>
        if (s_axis_tvalid = '1') then
          if (int_cntr_reg < unsigned(tot_data)) then
            int_cntr_next <= int_cntr_reg + 1;
          else
            int_enbl_next <= '0';
            int_case_next <= "00";
          end if;
        end if;
    end case;
  end process;

  sts_data <= int_addr_reg & int_enbl_reg;

  s_axis_tready <= '1';
  m_axis_tdata <= s_axis_tdata;
  m_axis_tvalid <= int_enbl_reg and s_axis_tvalid;

end rtl;
