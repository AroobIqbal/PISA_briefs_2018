*==============================================================================*
*PISA Briefs 2018
*
*Steps:
*0)	Bringing country list
*1) Separating statistics by subgroups
*2) Calculate statistics by subgroups of traitvars
*===============================================================================*

*-------------------------------------------------------------------------------
*0) Bringing country list along with comparators
*-------------------------------------------------------------------------------
*Include 2018 years into the file
use "$input_raw/master_countrycode_list.dta", clear
keep if assessment == "PISA"
*Testing for one country:
keep if countrycode == "BGR"
levelsof countrycode, local (cnt)
set trace on
foreach cc of local cnt {
	*preserve
	levelsof year if countrycode == "`cc'", local(yr)
	
	foreach year of local yr {

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


		use "$output_dir/WLD_`year'_PISA_v01_M_wrk_A_GLAD.dta", clear
		
		* Creating locals to accomodate additonal subjects added in later years 
		if inlist(`year',2000,2003,2006,2009){
		     local subject "read math scie"
		else if inlist(`year', 2012, 2015) {
		     local subject "read math scie flit"
		    }
		  }

		  
		  * Creating locals to account for differences in number of pv values across years 
		if inlist(`year',2000,2003,2006,2009,2012) {
		     local pvvalues 1 2 3 4 5 
		else if inlist(`year',2015) {
		     local pvvalues 1 2 3 4 5 6 7 8 9 10
		    }
		  }
		  	  
		keep if countrycode == "`cc'"
		
		count
		if r(N) > 0 {

			*--------------------------------------------------------------------------------
			* 1) Separating indicators by trait groups
			*--------------------------------------------------------------------------------
			
			gen total = 1
			label define total 1 "total"
			label values total total
			local traitvars male urban native escs_quintile escs_q_read escs_q_math escs_q_scie ece* language school_type city 
							
			foreach sub of local subject {
				foreach indicator in score {
					foreach trait of local traitvars  {
					capture confirm variable `trait'
						if !_rc { 
						    mdesc `trait'
							if r(percent) != 100 {
							   foreach i of local pvvalues {
								separate(`indicator'_pisa_`sub'_`i'), by(`trait') gen(`indicator'`sub'`i'`trait')
								ren `indicator'`sub'`i'`trait'* `indicator'`sub'`trait'*_`i'	  
						 }
			      }
					
	*-----------------------------------------------------------------------------
	*2) *Calculation of indicators by subgroups of traitvars
	*-----------------------------------------------------------------------------
							levelsof `trait', local(lev)
							foreach lv of local lev {
								local label: label (`trait') `lv'

								
								if `year' == 2000 {
								
									cap qui: pv, pv(`indicator'`sub'`trait'`lv'_*) weight(learner_weight_`sub') brr rw(weight_replicate_`sub'*) fays(0.5): mean @pv [aw=@w]
								}
								
								if `year' != 2000 {
														
									cap qui: pv, pv(`indicator'`sub'`trait'`lv'_*) weight(learner_weight) brr rw(weight_replicate*) fays(0.5): mean @pv [aw=@w]
								}


								
								* Create variables to store estimates (mean and std error of mean) and num of obs (N)
								matrix pv_mean = e(b)
								matrix pv_var  = e(V)
								gen  m_`indicator'`sub'`label'  = pv_mean[1,1]
								gen  se_`indicator'`sub'`label' = sqrt(pv_var[1,1])
								gen  n_`indicator'`sub'`label'  = e(N)
								
								label var  m_`indicator'`sub'`label'  "Mean of `sub' `indicator' by - `label'"
								label var se_`indicator'`sub'`label' "Standard error of `sub' `indicator' by  - `label'"
								label var n_`indicator'`sub'`label'  "Number of observations used to calculate `sub' `indicator' by - `label'"

							}	
						}
					}
				}
			}
			
			keep countrycode national_level idgrade age m_* se_* n_*	
			collapse m_* se_* n_* idgrade age, by(countrycode national_level)
			save "$temp_dir\temp_`year'_PISA_v01_M_v01_A_CI_MEANS_Subgroups_`cc'.dta", replace
		}
	}
	*restore
}