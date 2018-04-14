library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity pps_gen is
generic (
  CLK_FREQ : natural := 142857132
);
port (
  -- System signals
  aclk               : in std_logic;
  aresetn            : in std_logic;

  pps_i              : in  std_logic; -- GPS PPS input
  gpsen_i            : in  std_logic; -- PPS enable 0 -> GPS, 1 -> False PPS 
  pps_o              : out std_logic;
  clk_cnt_pps_o      : out std_logic_vector(27-1 downto 0);
  pps_gps_led_o      : out std_logic;
  false_pps_led_o    : out std_logic;
  int_o              : out std_logic
);
end pps_gen;

architecture rtl of pps_gen is

  --PPS related signals
  -- clock counter in a second
  signal one_sec_cnt: std_logic_vector(27-1 downto 0);      
  -- counter for clock pulses between PPS, it goes to zero at every PPS pulse 
  signal clk_cnt_pps : std_logic_vector(27-1 downto 0); 
  signal pps         : std_logic;
  signal false_pps   : std_logic := '0';

  type pps_st_t is (ZERO, EDGE, ONE);
  signal pps_st_reg, pps_st_next: pps_st_t;
  signal one_clk_pps       : std_logic;
  signal pps_ibuf          : std_logic;

begin
    
  int_o <= one_clk_pps;
 
  IBUF_inst : IBUF
   port map (
    O => pps_ibuf,
    I => pps_i
   );

  pps_gps_led_o <= pps_ibuf when (gpsen_i = '0') else '0';

  false_pps_led_o <=  false_pps when (gpsen_i = '1') else '0';

  --PPS MUX 
  pps             <=  false_pps when (gpsen_i = '1') else pps_ibuf;

  pps_o           <= one_clk_pps;
  clk_cnt_pps_o   <= clk_cnt_pps;

  -- false PPS
  process(aclk)
  begin
    if (rising_edge(aclk)) then
      if (aresetn = '0') then
        one_sec_cnt <= (others => '0');   
        clk_cnt_pps <= (others => '0');   
      else
        if (unsigned(one_sec_cnt) = CLK_FREQ-1) then
          one_sec_cnt <= (others => '0');
        else
          one_sec_cnt <= std_logic_vector(unsigned(one_sec_cnt) + 1);
        end if;
       
        -- false PPS is UP for 200 ms
        if (unsigned(one_sec_cnt) < CLK_FREQ/5) then
          false_pps <= '1';
        else
          false_pps <= '0';
        end if;
        
        if (one_clk_pps = '1') then 
          clk_cnt_pps <=  (others => '0');
        else
          clk_cnt_pps <= std_logic_vector(unsigned(clk_cnt_pps) + 1);
        end if;

      end if;
    end if;
  end process;

  -- edge detector
  -- state register
  process(aclk)
  begin
    if (rising_edge(aclk)) then
    if (aresetn = '0') then
        pps_st_reg <= ZERO;
    else
        pps_st_reg <= pps_st_next;
    end if;
    end if;
  end process;

  -- next-state/output logic
  process(pps_st_reg, pps)
  begin
     pps_st_next <= pps_st_reg;
     one_clk_pps <= '0';
     case pps_st_reg is
        when ZERO =>
           if pps = '1' then
              pps_st_next <= EDGE;
           end if;
        when EDGE =>
           one_clk_pps <= '1';
           if pps = '1' then
              pps_st_next <= ONE;
           else
              pps_st_next <= ZERO;
           end if;
        when ONE =>
           if pps = '0' then
              pps_st_next <= ZERO;
           end if;
     end case;
  end process;

end architecture rtl;
