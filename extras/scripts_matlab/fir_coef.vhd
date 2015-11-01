library ieee;
use ieee.numeric_std.all;

package my_coeffs is
	constant B: natural:=16;
	constant N_coeffs: natural := 128;
	type coeff_t is array (0 to N_coeffs-1) of integer range -2**(B-1) to 2**(B-1)-1;
	constant coefficients: coeff_t:=
		(0,0,0,1,1,1,0,-1,-2,-2,-1,1,3,5,4,1,-3,-7,-9,-6,
		0,8,13,13,7,-5,-16,-22,-19,-6,13,28,33,23,0,-27,-46,-45,-24,13,
		49,68,57,18,-36,-80,-93,-64,-1,71,120,119,63,-30,-121,-167,-141,-46,82,187,
		218,152,8,-157,-268,-267,-144,60,258,359,305,105,-164,-386,-454,-321,-26,311,539,543,
		299,-107,-503,-709,-610,-222,305,745,886,636,71,-583,-1034,-1057,-599,180,955,1371,1203,465,
		-564,-1444,-1757,-1298,-189,1135,2093,2202,1306,-313,-2005,-3004,-2749,-1168,1221,3452,4465,3554,737,-3124,
		-6507,-7714,-5476,529,9436,19349,27859,32767
		);
end package my_coeffs;