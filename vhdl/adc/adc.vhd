library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.IBUFDS;

use work.extra_functions.all;
use work.constantes.all;

use std.standard.all;

entity adc is
	generic(BIT_OUT       : natural := BIT_OUT;
		    N_ETAPAS      : natural := CIC_N_ETAPAS; --etapas del cic
		    COMB_DELAY    : natural := CIC_COMB_DELAY; --delay restador
		    CIC_R         : natural := CIC_R; --decimacion
		    COEFF_BITS    : natural := FIR_COEFF_BITS;
		    FIR_R         : natural := FIR_R; --decimacion
		    N_DSP         : natural := DSP_INPUT_BITS; --entrada dsp específico para spartan6
		    M_DSP         : natural := DSP_OUTPUT_BITS; --salida dsp específico para spartan6
		    FIR_HALF_TAPS : natural := FIR_HALF_TAPS
	);

	port(
		input_p  : in  std_logic;
		input_n  : in  std_logic;
		output   : out std_logic_vector(BIT_OUT - 1 downto 0);
		feedback : out std_logic := '0';
		clk      : in  std_logic;
		rst      : in  std_logic;
		oe       : out std_logic := '0'
	);
end entity adc;

architecture RTL of adc is
	signal out_lvds_i, out_lvds, oe_cic, oe_fir : std_logic := '0'; -- senial de salida del LVDS
	signal ce_in                    : std_logic := '1';
	signal oe_i,oe_ii,oe_iii        : std_logic := '0';
	signal out_cic                  : std_logic_vector(CIC_OUTPUT_BITS - 1 downto 0);
	signal output_fir : std_logic_vector(BIT_OUT-1 downto 0);
	signal output_fir_i,output_fir_iii : std_logic_vector(BIT_OUT -1 downto 0);
begin
	--rst <= not nrst;
	feedback <= not out_lvds_i; 
	output <= output_fir_iii;
	oe <= oe_iii;
	
	IBUFDS_inst : IBUFDS
		generic map(
			DIFF_TERM    => FALSE,       -- Differential Termination 
			IBUF_LOW_PWR => FALSE,      -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
			IOSTANDARD   => "DEFAULT")
		port map(
			O  => out_lvds,             -- Buffer output
			I  => input_p,              -- Diff_p buffer input (connect directly to top-level port)
			IB => input_n               -- Diff_n buffer input (connect directly to top-level port)
		);

	CIC : entity work.cic
		generic map(
			N     => N_ETAPAS,          --etapas
			DELAY => COMB_DELAY,        -- delay restador
			R     => CIC_R             --decimacion            
		)
		port map(
			input  => out_lvds_i,
			output => out_cic,
			clk    => clk,
			rst    => rst,
			ce_in  => ce_in,
			ce_out => oe_cic
		);

	fir : entity work.fir
		generic map(
			N     => CIC_OUTPUT_BITS,
			B     => COEFF_BITS,
			M     => BIT_OUT,
			TAPS  => 2 * FIR_HALF_TAPS,
			N_DSP => N_DSP,
			M_DSP => M_DSP	
		)
		port map(
			data_in  => out_cic,
			data_out => output_fir,
			we       => oe_cic,
			oe       => oe_fir,
			ce       => ce_in,
			clk      => clk,
			rst      => rst
		);

	
	
--	process(clk) is
--	begin
--		if rising_edge(clk) then
--			if rst = '1' then
--				oe <= '0';
--				out_lvds_i <= '0';
--				output_fir_i <= (others => '0');
--			else
--				out_lvds_i <=  out_lvds;
--				oe <= oe_ii;
--				oe_ii <= oe_i;
--				if (oe_ii= '1') then
--					output_fir_i <= output_fir;
--				end if; 
--				
--			end if;
--		end if;
--	end process;
	
		process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				out_lvds_i <= '0';
				output_fir_i <= (others => '0');
				output_fir_iii<= (others=>'0');
				oe_iii <= '0';
				
			else
				out_lvds_i <=  out_lvds;
				oe_i <= oe_fir;
				output_fir_i <= output_fir;
				oe_iii<= oe_ii;
				
				if(oe_ii='1') then
					output_fir_iii<= output_fir_i;
				end if;
			end if;
		end if;
	end process;
	
	--instanciar decimador salida fir (oe_fir --> oe)
	fir_decimator : entity work.decimator
		generic map(
			R => FIR_R
		)
		port map(
			ce_in  => oe_i,--oe_fir,
			ce_out => oe_ii,--oe_i,
			clk    => clk,
			rst    => rst
		);
end architecture RTL;
