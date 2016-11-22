library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_lago_trigger is
  generic (
  AXIS_TDATA_WIDTH  : natural  := 32;
  AXIS_TDATA_SIGNED : string   := "FALSE";
  B                : natural :=5;      -- numero de bits de direcciones. 2**W = 32 direcciones para W=5
  ADCBITS          : natural := 10;    -- numero de bits en los datos
  SAMPLE_ARRAY_LENGTH     : natural := 12;
  L_ARRAY_PPS      : natural := 10;
  L_ARRAY_SCALERS  : natural := 3
);
port (
  -- System signals
  aclk          : in std_logic;
  aresetn       : in std_logic;

  pol_data      : in std_logic;
  msk_data      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  lvl_data      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

  trg_flag      : out std_logic;

  data_adc1          : in   std_logic_vector(ADCBITS-1 downto 0);
  data_adc2          : in   std_logic_vector(ADCBITS-1 downto 0);
  data_adc3          : in   std_logic_vector(ADCBITS-1 downto 0);
  trigg_set1         : in   std_logic_vector(ADCBITS-1 downto 0);
  trigg_set2         : in   std_logic_vector(ADCBITS-1 downto 0);
  trigg_set3         : in   std_logic_vector(ADCBITS-1 downto 0);
  subtrigg_set1      : in   std_logic_vector(ADCBITS-1 downto 0);
  subtrigg_set2      : in   std_logic_vector(ADCBITS-1 downto 0);
  subtrigg_set3      : in   std_logic_vector(ADCBITS-1 downto 0);
  pwr_enA            : out  std_logic;
  data_out           : out  std_logic_vector(2**W-1 downto 0);
  pfifo_status       : in   std_logic_vector(2 downto 0);
  ptemperatura       : in   std_logic_vector(15 downto 0);
  ppresion           : in   std_logic_vector(15 downto 0);
  phora              : in   std_logic_vector(7 downto 0);
  pminutos           : in   std_logic_vector(7 downto 0);
  psegundos          : in   std_logic_vector(7 downto 0);
  pps_signal         : in   std_logic;
  gpsen              : in   std_logic;
  pps_falso_led      : out  std_logic;
  latitude1_port     : in   std_logic_vector(7 downto 0);
  latitude2_port     : in   std_logic_vector(7 downto 0);
  latitude3_port     : in   std_logic_vector(7 downto 0);
  latitude4_port     : in   std_logic_vector(7 downto 0);
  longitude1_port    : in   std_logic_vector(7 downto 0);
  longitude2_port    : in   std_logic_vector(7 downto 0);
  longitude3_port    : in   std_logic_vector(7 downto 0);
  longitude4_port    : in   std_logic_vector(7 downto 0);
  ellipsoid1_port    : in   std_logic_vector(7 downto 0);
  ellipsoid2_port    : in   std_logic_vector(7 downto 0);
  ellipsoid3_port    : in   std_logic_vector(7 downto 0);
  ellipsoid4_port    : in   std_logic_vector(7 downto 0);
  num_vis_sat_port   : in   std_logic_vector(7 downto 0);
  num_track_sat_port : in   std_logic_vector(7 downto 0);
  rsf_port           : in   std_logic_vector(7 downto 0)

  -- Slave side
  s_axis_tready     : out std_logic;
  s_axis_tdata      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid     : in std_logic;

  -- Master side
  s_axis_tready     : out std_logic;
  s_axis_tdata      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid     : in std_logic
);
end axis_lago_trigger;

architecture rtl of axis_lago_trigger is
  
  --ADC related signals
  type  adc_sample_array_t is array (SAMPLE_ARRAY_LENGHT-1 downto 0) of std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  signal adc1_samples_reg, adc1_samples_next : adc_sample_array_t;
  signal adc2_samples_reg, adc2_samples_next : adc_sample_array_t;

  --PPS related signals
  signal false_pps_clk_reg, false_pps_clk_next : unsigned(2**B-1 downto 0); -- counter for false pps
  signal cont_pps_reg, cont_pps_next : unsigned(15 downto 0);               -- contador para pps
  signal cont_clk_entre_pps_reg, cont_clk_entre_pps_next : unsigned(29 downto 0); -- contador de pulsos de clock entre cada PPS, se resetea en cada pps
  signal pps, pps_falso : std_logic;

  type statepps_type is (zero, edge, one);
  signal statepps_reg, statepps_next: statepps_type;
  signal one_clk_pps : std_logic;

  signal int_comp_reg : std_logic_vector(1 downto 0);
  signal int_comp_wire : std_logic;

begin
    
--------------------------------------------------------------------------
  -- PPS falso
  -- registers
  process(aclk, aresetn)
  begin
    if (aresetn = '0') then
      false_pps_clk_reg <= (others => '0');          -- clock counter between pps
      pps_cntr_reg      <= (others => '0');               -- pps counter
      cont_clk_entre_pps_reg <= (others => '0');     -- sample counter between pps
    elsif (rising_edge(aclk)) then
      false_pps_clk_reg <= false_pps_clk_next;
      cont_pps_reg <= cont_pps_next;
      cont_clk_entre_pps_reg <= cont_clk_entre_pps_next;
    end if;
  end process;
  --next state logic
  --FIXME: check how to put here the number of clocks present in one second. It must depend of the aclk signal.
  false_pps_clk_next <= (others => '0') when (false_pps_clk_reg = 39999999) else false_pps_clk_reg + 1; 

  false_pps <=  '1' when (false_pps_clk_reg < 8000000) else
                '0';

  cont_pps_next <=  cont_pps_reg + 1 when (one_clk_pps = '1') else
                    cont_pps_reg;

  cont_clk_entre_pps_next <=  (others => '0') when (one_clk_pps = '1') else
                              cont_clk_entre_pps_reg + 1;

---------------------------------------------------------------------------
---------------------------------------------------------------------------
  --PPS MUX 
  pps_s <=  false_pps when (gpsen = '1') else pps_i;

  pps_falso_led <=  false_pps when (gpsen = '1') else '0';
---------------------------------------------------------------------------
---------------------------------------------------------------------------
  -- one clock pps: en cada pps se mantiene en alto la bandera one_clk_pps durante un ciclo de reloj de 40MHz
  -- detector de flancos
  -- state register
  process(aclk,aresetn)
  begin
    if (aresetn = '1') then
        statepps_reg <= ZERO;
    elsif (rising_edge(aclk)) then
        statepps_reg <= statepps_next;
    end if;
  end process;

  -- next-state/output logic
  process(statepps_reg, pps_s)
  begin
     statepps_next <= statepps_reg;
     one_clk_pps <= '0';
     case statepps_reg is
        when zero=>
           if pps= '1' then
              statepps_next <= edge;
           end if;
        when edge =>
           one_clk_pps <= '1';
           if pps= '1' then
              statepps_next <= one;
           else
              statepps_next <= zero;
           end if;
        when one =>
           if pps= '0' then
              statepps_next <= zero;
           end if;
     end case;
  end process;

-----------------------------------------------------------------------------

  
  SIGNED_G: if (AXIS_TDATA_SIGNED = "TRUE") generate
    int_comp_wire <= '1' when signed(s_axis_tdata and msk_data) >= signed(lvl_data) else '0';
  end generate;

  UNSIGNED_G: if (AXIS_TDATA_SIGNED = "FALSE") generate
    int_comp_wire <= '1' when unsigned(s_axis_tdata and msk_data) >= unsigned(lvl_data) else '0';
  end generate;

  process(aclk, s_axis_tvalid)
  begin
   if (rising_edge(aclk)) then
    if (s_axis_tvalid = '1') then
      int_comp_reg <= int_comp_reg(0) & int_comp_wire;
    end if;
   end if;
  end process;

  s_axis_tready <= '1';

  trg_flag <= s_axis_tvalid and (pol_data xor int_comp_reg(0)) and (pol_data xor not(int_comp_reg(1)));

end rtl;
