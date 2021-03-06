library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.floor;

--library UNISIM;
--use UNISIM.vcomponents.PLL_BASE;

use work.extra_functions.all;
use work.constantes.all;

entity top_level is
	generic(
		BIT_OUT       : natural := BIT_OUT;
		N_ETAPAS      : natural := CIC_N_ETAPAS; --etapas del cic
		COMB_DELAY    : natural := CIC_COMB_DELAY; --delay restador
		CIC_R         : natural := CIC_R; --decimacion
		COEFF_BITS    : natural := FIR_COEFF_BITS;
		FIR_R         : natural := FIR_R; --decimacion
		N_DSP         : natural := DSP_INPUT_BITS; --entrada dsp específico para spartan6
		M_DSP         : natural := DSP_OUTPUT_BITS; --salida dsp específico para spartan6
		FIR_HALF_TAPS : natural := FIR_HALF_TAPS;

		Bits_UART     : integer := 8;  -- Cantidad de Bits
		Baudrate      : integer := 921600; -- BaudRate de la comunicacion UART
		Core          : integer := 90625000 -- Frecuencia de core
	);
	port(
		input_p  : in  std_logic;
		input_n  : in  std_logic;
		output   : out std_logic_vector(BIT_OUT - 1 downto 0);
		parallel_oe : out std_logic;
		feedback : out std_logic;
		clk    : in  std_logic;
		nrst    : in  std_logic;

		Tx       : out std_logic;        -- Transmisor
		Rx 		 : in std_logic
	);
end entity top_level;

architecture RTL of top_level is
	signal clk_90 : std_logic := '0';
	signal oe,oe_adc     : std_logic                              := '0';
	signal rst   : std_logic                              := '0';
	signal output_i : std_logic_vector(BIT_OUT - 1 downto 0) := (others => '0');
	signal tx_load,tx_load_i : std_logic_vector (BITS_UART-1 downto 0):= (others=>'0');
	signal tx_busy, tx_start,tx_start_i : std_logic:='0';
	type state_type is (IDLE, FIRST, SECOND, WAITING); 
	signal state, state_i : state_type; 
	
	signal rx_output :  std_logic_vector(Bits_UART-1 downto 0) := (others=>'0');
	
	constant cuentas : natural := 4*CORE/BAUDRATE;
	signal cnt : std_logic_vector( log2(cuentas)-1 downto 0);
	signal rst_cnt,rst_cnt_i : std_logic:= '1';
--signal clk_f,clk_o: std_logic;

begin
	rst <= not nrst;
	parallel_oe <= oe;

	output <= output_i;
	
	PLL : entity work.Clk_PLL
		port map(
			CLK_IN1  => clk,
			CLK_OUT1 => clk_90
		);
	
	ADC : entity work.adc
		generic map(
			BIT_OUT       => BIT_OUT,
			N_ETAPAS      => N_ETAPAS,  --etapas del cic
			COMB_DELAY    => COMB_DELAY, --delay restador
			CIC_R         => CIC_R,     --decimacion
			COEFF_BITS    => COEFF_BITS,
			FIR_R         => FIR_R,     --decimacion
			N_DSP         => N_DSP,     --entrada dsp específico para spartan6
			M_DSP         => M_DSP,     --salida dsp específico para spartan6
			FIR_HALF_TAPS => FIR_HALF_TAPS
		)
		port map(
			input_p  => input_p,
			input_n  => input_n,
			output   => output_i,
			feedback => feedback,
			clk      => clk_90,
			rst      => rst,
			oe       => oe_adc
		);

	TX_SERIE : entity work.Tx_uart
		generic map(
			BITS     => Bits_UART,
			CORE     => core,
			BAUDRATE => Baudrate
		)
		port map(
			Tx      => Tx,
			Load    => tx_load,
			LE      => tx_start,
			Tx_busy => Tx_busy,
			clk     => clk_90,
			rst     => rst
		);
		
	RX_SERIE: entity work.Rx_uart
		generic map(
			BITS     => Bits_UART,
			CORE     => core,
			BAUDRATE => Baudrate
		)
		port map(
			rx     => rx,
			oe     => open,
			output => rx_output,
			clk    => clk_90,
			rst    => rst
		);
		
	
	process (clk_90) is
	begin
		if rising_edge(clk_90) then
			if rst = '1' then
				state <= IDLE;
				tx_load <= (others=>'0');
				tx_start <= '0';		
				rst_cnt <= '1';
			else	
				state <= state_i;
				rst_cnt <= rst_cnt_i;
				tx_load <= tx_load_i;
				tx_start <= tx_start_i;
			end if;
		end if;
	end process;
	
	oe <= oe_adc when (rx_output="01110011") else '0';  -- s arranca la transmision
	
	OUT_PROC:process (tx_busy,oe,state,output_i,tx_start,tx_load)
	begin	
		rst_cnt_i <= '1';
		tx_load_i <= tx_load;
		tx_start_i <= tx_start;
		state_i <= state;
		case state is
			when IDLE => 
				if oe ='1' then
					tx_load_i <= output_i(BIT_OUT-1 downto BIT_OUT/2);
					tx_start_i <= '1';
					state_i <= FIRST;	
				else
					tx_load_i <= (others=>'0');
					tx_start_i <= '0';
					state_i <= IDLE;							
				end if;
			when FIRST=>
				if (tx_busy = '0' and tx_start ='0') then
					rst_cnt_i <= '0';
					state_i <= WAITING;
				else
					tx_load_i <= (others=>'0');
					tx_start_i <= '0';
					state_i <= FIRST;
				end if;
				
			when WAITING =>
				tx_load_i <= output_i(BIT_OUT/2-1 downto 0);
				tx_start_i <= '1';
				state_i <= SECOND;
					
			when SECOND=>
				if tx_busy = '0' and tx_start ='0' then
					tx_load_i <= (others=>'0');
					tx_start_i <= '0';
					state_i <= IDLE;
				else
					tx_load_i <= (others=>'0');
					tx_start_i <= '0';
					state_i <= SECOND;
				end if;	
		end case;
	end process;
	
	process (clk_90)
	begin
		if rising_edge(clk_90) then
			if rst_cnt = '1' then
				cnt <= (others =>'0');
			else
				cnt <= std_logic_vector(unsigned(cnt)+to_unsigned(1,cnt'length));
			end if;
		end if;
	end process;
	
end architecture RTL;
