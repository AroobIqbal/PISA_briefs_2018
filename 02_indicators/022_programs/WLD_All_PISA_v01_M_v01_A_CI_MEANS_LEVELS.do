*Author: Syedah Aroob Iqbal
*Last edited by XXXX on XXXXX

/*-------------------------------------
This do file:
1) Appends all mean and levels data
2) Label and clean the variables
---------------------------------------*/

global path = "N:\GDB\HLO_Database"

foreach year in 2000 2003 {
	cd "${path}\temp\" 
	fs temp_`year'_PISA_v01_M_v01_A_CI_MEANS_*.dta
	di `r(files)'
	local firstfile: word 1 of `r(files)'
	use `firstfile', clear
	foreach f in `r(files)' {
		if "`f'" ~= "`firstfile'" append using `f'
		*rm "`f'"
	}
	codebook, compact
	gen year = `year'
	*cf _all using "${path}\WLD\WLD_`year'_PISA\WLD_`year'_PISA_v01_M_v01_A_DSES_20_80.dta"
	
	if `year' == 2000 {
		foreach ind in m_ se_ n_ {	
			foreach sub in read math scie {
				foreach sub1 in read math scie {
					if "`sub'" != "`sub1'" {
						drop `ind'score`sub'escs_quintile_`sub1'*
					}
					else if "`sub'" == "`sub1'" {
						rename `ind'score`sub'escs_quintile_`sub1'* `ind'score`sub'escs_quintile*
					}
				}
			}
		}
	}
	save "${path}\temp\WLD_`year'_PISA_v01_M_v01_A_CI_MEANS.dta", replace
}
*Appending:
use "${path}\temp\WLD_2000_PISA_v01_M_v01_A_CI_MEANS.dta", clear
append using "${path}\temp\WLD_2003_PISA_v01_M_v01_A_CI_MEANS.dta"

*Labelling variables:

save "${path}\temp\WLD_ALL_PISA_v01_M_v01_A_CI_MEANS.dta", replace


*Appending Levels:
*Author: Syedah Aroob Iqbal
*Last edited by XXXX on XXXXX

/*-------------------------------------
This do file:
1) Appends all mean and levels data
2) Label and clean the variables
---------------------------------------*/

global path = "N:\GDB\HLO_Database"

foreach year in 2000 {
	cd "${path}\temp\" 
	fs temp_`year'_PISA_v01_M_v01_A_CI_LEVELS_*.dta
	di `r(files)'
	local firstfile: word 1 of `r(files)'
	use `firstfile', clear
	foreach f in `r(files)' {
		if "`f'" ~= "`firstfile'" append using `f'
		*rm "`f'"
	}
	codebook, compact
	gen year = `year'
	*cf _all using "${path}\WLD\WLD_`year'_PISA\WLD_`year'_PISA_v01_M_v01_A_DSES_20_80.dta"
	
	if `year' == 2000 {
		foreach ind in m_ se_ n_ {	
			foreach sub in read math scie {
				foreach sub1 in read math scie {
					if "`sub'" != "`sub1'" {
						drop `ind'blev?`sub'escs_quintile_`sub1'*
					}
					else if "`sub'" == "`sub1'" {
						rename `ind'blev?`sub'escs_quintile_`sub1'* `ind'blev?`sub'escs_quintile*
					}
				}
			}
		}
	}
	save "${path}\temp\WLD_`year'_PISA_v01_M_v01_A_CI_LEVELS.dta", replace
}
*Appending:
use "${path}\temp\WLD_2000_PISA_v01_M_v01_A_CI_LEVELS.dta", clear
*append using "${path}\temp\WLD_2003_PISA_v01_M_v01_A_CI_LEVELS.dta"

*Labelling variables:

save "${path}\temp\WLD_ALL_PISA_v01_M_v01_A_CI_LEVELS.dta", replace

