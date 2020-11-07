library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_stream_generator is
  generic(
           AXIS_TDATA_WIDTH : natural := 32
         );
  port 
  (
    -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol ports, do not add or delete. 
    aclk	: in	std_logic;
    aresetn	: in	std_logic;
    s_axis_tready	: out	std_logic;
    s_axis_tdata	: in	std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
    s_axis_tlast	: in	std_logic;
    s_axis_tvalid	: in	std_logic;
    m_axis_tvalid	: out	std_logic;
    m_axis_tdata	: out	std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
    m_axis_tlast	: out	std_logic;
    m_axis_tready	: in	std_logic
  -- DO NOT EDIT ABOVE THIS LINE ---------------------
  );

--  attribute SIGIS : string; 
--  attribute SIGIS of ACLK : signal is "Clk"; 

end axi_stream_generator;

------------------------------------------------------------------------------
-- Architecture Section
------------------------------------------------------------------------------

-- In this section, we povide an example implementation of ENTITY axi_stream_generator
-- that does the following:
--
-- 1. Read all inputs
-- 2. Add each input to the contents of register 'sum' which
--    acts as an accumulator
-- 3. After all the inputs have been read, write out the
--    content of 'sum' into the output stream NUMBER_OF_OUTPUT_WORDS times
--
-- You will need to modify this example or implement a new architecture for
-- ENTITY axi_stream_generator to implement your coprocessor

architecture EXAMPLE of axi_stream_generator is

  -- Total number of input data.
  constant NUMBER_OF_INPUT_WORDS  : natural := 8;

  -- Total number of output data
  constant NUMBER_OF_OUTPUT_WORDS : natural := 8;

  type STATE_TYPE is (Idle, Read_Inputs, Write_Outputs);

  signal state        : STATE_TYPE;

  -- Accumulator to hold sum of inputs read at any point in time
  signal sum          : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

  -- Counters to store the number inputs read & outputs written
  signal nr_of_reads  : natural range 0 to NUMBER_OF_INPUT_WORDS - 1;
  signal nr_of_writes : natural range 0 to NUMBER_OF_OUTPUT_WORDS - 1;

  -- tlast signal
  signal tlast : std_logic;

begin
  -- CAUTION:
  -- The sequence in which data are read in and written out should be
  -- consistent with the sequence they are written and read in the
  -- driver's axi_stream_generator.c file

  -- s_axis_tready  <= '1'   when state = Read_Inputs   else '0';
  s_axis_tready  <= '0' when state = Write_Outputs else '1';
  m_axis_tvalid <= '1' when state = Write_Outputs else '0';

  m_axis_tdata <= sum;
  m_axis_tlast <= tlast;

  The_SW_accelerator : process (ACLK) is
  begin  -- process The_SW_accelerator
    if ACLK'event and ACLK = '1' then     -- Rising clock edge
      if ARESETN = '0' then               -- Synchronous reset (active low)
                                          -- CAUTION: make sure your reset polarity is consistent with the
                                          -- system reset polarity
        state        <= Idle;
        nr_of_reads  <= 0;
        nr_of_writes <= 0;
        sum          <= (others => '0');
        tlast        <= '0';
      else
        case state is
          when Idle =>
            if (s_axis_tvalid = '1') then
              state       <= Read_Inputs;
              nr_of_reads <= NUMBER_OF_INPUT_WORDS - 1;
              sum         <= (others => '0');
            end if;

          when Read_Inputs =>
            if (s_axis_tvalid = '1') then
              -- Coprocessor function (Adding) happens here
              sum         <= std_logic_vector(unsigned(sum) + unsigned(s_axis_tdata));
              if (s_axis_tlast = '1') then
                state        <= Write_Outputs;
                nr_of_writes <= NUMBER_OF_OUTPUT_WORDS - 1;
              else
                nr_of_reads <= nr_of_reads - 1;
              end if;
            end if;

          when Write_Outputs =>
            if (m_axis_tready = '1') then
              if (nr_of_writes = 0) then
                state <= Idle;
                tlast <= '0';
              else
                -- assert tlast on last transmitted word
                if (nr_of_writes = 1) then
                  tlast <= '1';
                end if;
                nr_of_writes <= nr_of_writes - 1;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process The_SW_accelerator;
end architecture EXAMPLE;
