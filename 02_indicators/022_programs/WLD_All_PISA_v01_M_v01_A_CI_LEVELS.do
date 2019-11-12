
global path = "N:\GDB\HLO_Database"
foreach year in 2000 {

*Setting folder structure:
*=========================================================================*
* GLOBAL LEARNING ASSESSMENT DATABASE (GLAD)
* Project information at: https://github.com/worldbank/GLAD
*
* Metadata to be stored as 'char' in the resulting dataset (do NOT use ";" here)
local region      = "WLD"   /* LAC, SSA, WLD or CNT such as KHM RWA */
local year        = "`year'"  /* 2015 */
local assessment  = "PISA" /* PIRLS, PISA, EGRA, etc */
local master      = "v01_M" /* usually v01_M, unless the master (eduraw) was updated*/
local adaptation  = "wrk_A_GLAD" /* no need to change here */
local module      = "ALL"  /* for now, we are only generating ALL and ALL-BASE in GLAD */
local ttl_info    = "Joao Pedro de Azevedo [eduanalytics@worldbank.org]" /* no need to change here */
local dofile_info = "last modified by Syedah Aroob Iqbal in October 29, 2019"  /* change date*/
*
* Steps:
* 0) Program setup (identical for all assessments)
* 1) Open all rawdata, lower case vars, save in temp_dir
* 2) Combine all rawdata into a single file (merge and append)
* 3) Standardize variable names across all assessments
* 4) ESCS and other calculations
* 5) Bring WB countrycode & harmonization thresholds, and save dtas
*=========================================================================*

  glad_local_folder_setup , r("`region'") y("`year'") as("`assessment'") ma("`master'") ad("`adaptation'")
  global temp_dir     "`r(temp_dir)'"
  global output_dir   "`r(output_dir)'"
  global surveyid     "`r(surveyid)'"
  global output_file  "$surveyid_`adaptation'_`module'"

 * Save timestamps for naming the log by initial time
local today = subinstr("$S_DATE"," ","_",.)
local time  = subinstr("$S_TIME",":","-",.)


	use "$output_dir/WLD_`year'_PISA_v01_M_wrk_A_GLAD.dta", replace
	
	*Keeping for EAP: 
	keep if inlist(countrycode,"NZA","THA")
	gen total = 1
	
	foreach var of varlist level* {
		encode `var', gen(`var'_n)
		drop `var'
		ren `var'_n `var'
	}
	*Creating dummies for each level:
	foreach sub in read math scie {
		forvalues i = 1(1)5 {
			forvalues l = 1(1)8 {
				gen blev`l'_pisa_`sub'_`i' = (level_pisa_`sub'_`i' == `l') & !missing(level_pisa_`sub'_`i')
			}
		}
	}
	*PISA 2015 and 2012: Albania data has certain issues due to which the student questionnaire data and student test data could not be matched.
	drop if (`year' == 2015 & countrycode == "ALB") | (`year' == 2012 & countrycode == "ALB")

	levelsof countrycode, local (co)
	foreach c of local co {
	
		preserve
		
		keep if countrycode == "`c'"
	
		
		foreach sub in read math scie {
			foreach indicator in blev1 blev2 blev3 blev4 blev5 blev6 blev7 blev8 {
				foreach var of varlist total male urban native escs_quintile*  {
					forvalues i = 1(1)5 {
						cap qui: separate(`indicator'_pisa_`sub'_`i'), by(`var') gen(`indicator'`sub'`i'`var')
						cap qui: ren `indicator'`sub'`i'`var'* `indicator'`sub'`var'*_`i'
					}
					levelsof `var', local(lev)
					foreach lv of local lev {
						cap qui: pv, pv(`indicator'`sub'`var'`lv'_*) weight(learner_weight_`sub') brr rw(weight_replicate_`sub'*) fays(0.5): mean @pv [aw=@w]
						* Create variables to store estimates (mean and std error of mean) and num of obs (N)
						matrix pv_mean = e(b)
						matrix pv_var  = e(V)
						gen  m_`indicator'`sub'`var'`lv'  = pv_mean[1,1]
						gen  se_`indicator'`sub'`var'`lv' = sqrt(pv_var[1,1])
						gen  n_`indicator'`sub'`var'`lv'  = e(N)
					}
				}
			}
		}
		keep countrycode national_level idgrade age m_* se_* n_*	
		collapse m_* se_* n_* idgrade age, by(countrycode national_level)
		save "${path}\temp\temp_`year'_PISA_v01_M_v01_A_CI_LEVELS_`c'.dta", replace
		restore	
	}
}
