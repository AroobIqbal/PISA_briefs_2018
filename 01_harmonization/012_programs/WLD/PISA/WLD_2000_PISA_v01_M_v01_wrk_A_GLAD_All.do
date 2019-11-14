*=========================================================================*
* GLOBAL LEARNING ASSESSMENT DATABASE (GLAD)
* Project information at: https://github.com/worldbank/GLAD
*
* Metadata to be stored as 'char' in the resulting dataset (do NOT use ";" here)
local region      = "WLD"   /* LAC, SSA, WLD or CNT such as KHM RWA */
local year        = "2000"  /* 2015 */
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


  *---------------------------------------------------------------------------
  * 0) Program setup (identical for all assessments)
  *---------------------------------------------------------------------------

  // Parameters ***NEVER COMMIT CHANGES TO THOSE LINES!***
  //  - whether takes rawdata from datalibweb (==1) or from indir (!=1), global in 01_run.do
  local from_datalibweb = $from_datalibweb
  //  - whether checks first if file exists and attempts to skip this do file
  local overwrite_files = $overwrite_files
  //  - optional shortcut in datalibweb
  local shortcut = "$shortcut"
  //  - setting random seed at the beginning of each do for reproducibility
  set seed $master_seed

  // Set up folders in clone and define locals to be used in this do-file
  glad_local_folder_setup , r("`region'") y("`year'") as("`assessment'") ma("`master'") ad("`adaptation'")
  global temp_dir     "`r(temp_dir)'"
  global output_dir   "`r(output_dir)'"
  global surveyid     "`r(surveyid)'"
  global output_file  "$surveyid_`adaptation'_`module'"

  // If user does not have access to datalibweb, point to raw microdata location
  if `from_datalibweb' == 0 {
    global input_dir	= "${input}/`region'/`region'_`year'_`assessment'/$surveyid/Data/Stata"
  }

  // Confirm if the final GLAD file already exists in the local clone
  cap confirm file "$output_dir/$output_file.dta"
  // If the file does not exist or overwrite_files local is set to one, run the do
  *if (_rc == 601) | (`overwrite_files') {

    // Filter the master country list to only this assessment-year - 
    use "${clone}/01_harmonization/011_rawdata/master_countrycode_list.dta", clear
    keep if (assessment == "`assessment'") & (year == `year')
    // Most assessments use the numeric idcntry_raw but a few (ie: PASEC 1996) have instead idcntry_raw_str
    if use_idcntry_raw_str[1] == 1 {
      drop   idcntry_raw
      rename idcntry_raw_str idcntry_raw
    }
    keep idcntry_raw national_level countrycode
    save "$temp_dir/countrycode_list.dta", replace
	*/

    // Tokenized elements from the header to be passed as metadata
    global glad_description  "This dataset is part of the Global Learning Assessment Database (GLAD). It contains microdata from `assessment' `year'. Each observation corresponds to one learner (student or pupil), and the variables have been harmonized."
    global metadata          "region `region'; year `year'; assessment `assessment'; master `master'; adaptation `adaptation'; module `module'; ttl_info `ttl_info'; dofile_info `dofile_info'; description $glad_description"

    *---------------------------------------------------------------------------
    * 1) Open all rawdata, lower case vars, save in temp_dir
    *---------------------------------------------------------------------------

    /* NOTE: Some assessments will loop over `prefix'`cnt' (such as PIRLS, TIMSS),
       then create a temp file with all prefixs of a cnt merged.
       but other asssessments only need to loop over prefix (such as LLECE).
       See the two examples below and change according to your needs */

    foreach file in ESCS_PISA2000 intscho math read science {
         if `from_datalibweb'==1 {
           noi edukit_datalibweb, d(country(`region') year(`year') type(EDURAW) surveyid($surveyid) filename(`file'.dta) `shortcut')
         }
         else {
           use "$input_dir/`file'.dta", clear
         }
		 rename *, lower
         compress
         save "$temp_dir/`file'.dta", replace
       }

    noi disp as res "{phang}Step 1 completed ($output_file){p_end}"


    *---------------------------------------------------------------------------
    * 2) Combine all rawdata into a single file (merge and append)
    *---------------------------------------------------------------------------

    /* NOTE: the merge / append of all rawdata saved in temp in above step
       will vary slightly by assessment.
       See the two examples continuedw and change according to your needs */
	   
	use "$temp_dir\read.dta", clear
	ren (w_fstuwt w_fstr*) (learner_weight_read weight_replicate_read*)
	merge 1:1 country schoolid stidstd using "$temp_dir\math.dta", nogen
	ren (w_fstuwt w_fstr*) (learner_weight_math weight_replicate_math*)
merge 1:1 country schoolid stidstd  using "$temp_dir\science.dta", nogen
	ren (w_fstuwt w_fstr*) (learner_weight_scie weight_replicate_scie*)
merge m:1  cnt schoolid stidstd using "$temp_dir\ESCS_PISA2000.dta", keep(master match using) nogen
merge m:1 country schoolid using "$temp_dir\intscho.dta", assert(match) nogen
save "$temp_dir\PISA_2000.dta", replace
    noi disp as res "{phang}Step 2 completed ($output_file){p_end}"


    *---------------------------------------------------------------------------
    * 3) Standardize variable names across all assessments
    *---------------------------------------------------------------------------
    // For each variable class, we create a local with the variables in that class
    //     so that the final step of saving the GLAD dta  knows which vars to save

    // Every manipulation of variable must be enclosed by the ddi tags
    // Use clonevar instead of rename (preferable over generate)
    // The labels should be the same.
    // The generation of variables was commented out and should be replaced as needed
use "$temp_dir\PISA_2000.dta", replace

    // ID Vars:
    local idvars "idcntry_raw idschool idlearner idgrade "

    *<_countrycode_>
    clonevar idcntry_raw = cnt
	label var idcntry_raw "Country ID, as coded in rawdata"
    *</_countrycode_>

    *<_idschool_>
	encode schoolid, gen(idschool)
    label var idschool "School ID"
    *</_idschool_>

    *<_idgrade_>
	*Attempting recode 
	recode st02q01 (97 = -97) (99 = -99), gen(idgrade)
    label var idgrade "Grade ID"
    *</_idgrade_>

    *<_idclass_> - Not available
    *label var idclass "Class ID"
    *</_idclass_>

    *<_idlearner_>
    encode stidstd, gen(idlearner)
    label var idlearner "Learner ID"

    *</_idlearner_>

    *// Drop any value labels of idvars, to be okay to append multiple surveys
    foreach var of varlist idschool idlearner {
      label values `var' .
    }


    // VALUE Vars: 	  /* CHANGE HERE FOR YOUR ASSESSMENT!!! PIRLS EXAMPLE */
    local valuevars	"score_pisa* level_pisa*"

    *<_score_assessment_subject_pv_>
	foreach sub in read math scie {
		foreach pv in 1 2 3 4 5 {
			clonevar score_pisa_`sub'_`pv' = pv`pv'`sub'
			label var score_pisa_`sub'_`pv' "Plausible value `pv': `assessment' score for `sub'"
		}
	}
	
    *}
    *</_score_assessment_subject_pv_>

    *<_level_assessment_subject_pv_> - Proficiency levels to be created
	*For science - According to PISA 2015 report
		foreach pv in 1 2 3 4 5 {
			gen level_pisa_scie_`pv' = "<1b" if pv`pv'scie < 261  
			replace level_pisa_scie_`pv' = "1b" if pv`pv'scie >= 261 & pv`pv'scie < 335 
			replace level_pisa_scie_`pv' = "1a" if pv`pv'scie >= 335 & pv`pv'scie < 410 
			replace level_pisa_scie_`pv' = "2" if pv`pv'scie >= 410 & pv`pv'scie < 484 
			replace level_pisa_scie_`pv' = "3" if pv`pv'scie >= 484 & pv`pv'scie < 559
			replace level_pisa_scie_`pv' = "4" if pv`pv'scie >= 559 & pv`pv'scie < 633
			replace level_pisa_scie_`pv' = "5" if pv`pv'scie >= 633 & pv`pv'scie < 708
			replace level_pisa_scie_`pv' = "6" if pv`pv'scie >= 708 & !missing(pv`pv'scie)
			replace level_pisa_scie_`pv' = "-99" if missing(level_pisa_scie_`pv')
		}
	*For reading - According to PISA 2015 report
		foreach pv in 1 2 3 4 5 {
			gen level_pisa_read_`pv' = "<1b" if pv`pv'read < 262  
			replace level_pisa_read_`pv' = "1b" if pv`pv'read >= 262 & pv`pv'read < 335 
			replace level_pisa_read_`pv' = "1a" if pv`pv'read >= 335 & pv`pv'read < 407 
			replace level_pisa_read_`pv' = "2" if pv`pv'read >= 407 & pv`pv'read < 480 
			replace level_pisa_read_`pv' = "3" if pv`pv'read >= 480 & pv`pv'read < 553
			replace level_pisa_read_`pv' = "4" if pv`pv'read >= 553 & pv`pv'read < 626
			replace level_pisa_read_`pv' = "5" if pv`pv'read >= 626 & pv`pv'read < 698
			replace level_pisa_read_`pv' = "6" if pv`pv'read >= 698 & !missing(pv`pv'read)
		}
	*For mathematics - According to PISA 2015 report
		foreach pv in 1 2 3 4 5 {
			gen level_pisa_math_`pv' = "<1" if pv`pv'math < 358  
			replace level_pisa_math_`pv' = "1" if pv`pv'math >= 358 & pv`pv'math < 420 
			replace level_pisa_math_`pv' = "2" if pv`pv'math >= 420 & pv`pv'math < 482 
			replace level_pisa_math_`pv' = "3" if pv`pv'math >= 482 & pv`pv'math < 545
			replace level_pisa_math_`pv' = "4" if pv`pv'math >= 545 & pv`pv'math < 607
			replace level_pisa_math_`pv' = "5" if pv`pv'math >= 607 & pv`pv'math < 669
			replace level_pisa_math_`pv' = "6" if pv`pv'math >= 669 & !missing(pv`pv'math)
			replace level_pisa_math_`pv' = "-99" if missing(level_pisa_math_`pv')

		}
    *</_level_assessment_subject_pv_>*/


    // TRAIT Vars: - Add more as needed - Go through PISA
    local traitvars	"age urban* male escs escs_quintile_read native city escs_quintile_math escs_quintile_scie"

    *<_age_>
	recode age (997 999 = .z), gen(age_n)
	drop age
	ren age_n age
    replace age = age/12	
	replace age = -99 if missing(age)
    label var age "Learner age at time of assessment"
    *</_age_>

    *<_urban_>
    recode sc01q01 (1 = 0 "Rural") (2/6 = 1 "Urban") (7 = -97) (8/9 = -99), gen(urban)
    label var urban "School is located in urban/rural area"
    *</_urban_>
	
	*<_city_>
	recode sc01q01 (4/6 = 1 "City") (2/3 = 2 "Town") (1 = 3 "Village")  (7 = -97) (8/9 = -99), gen(city)
	label var city "School is located in city (1), town (2), village (3)"

    *<_urban_o_>
    decode sc01q01, g(urban_o)
    label var urban_o "Original variable of urban: population size of the school area"
    *</_urban_o_>*/

    *<_male_>
	recode st03q01 (2 = 1 "Male") (1 = 0 "Female") (7 = -97) (8/9 = -99), gen(male)
    label var male "Learner gender is male/female"
    *</_male_>
	
	*<_native_>
    gen native = 1 if st16q02 == 1 | st16q03 == 1 
	replace native = 2 if st16q01 == 1 & (st16q02 == 2 & st16q03 == 2)
	replace native = 3 if st16q01 == 2 & (st16q02 == 2 & st16q03 == 2)
    label var native "Learner is native (1), first-generation (2), second-generation (3)"
	label define native 1 "native" 2 "first-generation" 3 "second-generation"
	label var native native
    *</_native_>



    // SAMPLE Vars:		 	  /* CHANGE HERE FOR YOUR ASSESSMENT!!! PIRLS EXAMPLE */
    local samplevars "learner_weight* weight_replicate*"
	

    /*<_learner_weight_> *By subject, done earlier
    clonevar learner_weight  = learner_weight_reading if 
    label var learner_weight "Total learner weight"
    *</_learner_weight_>
	
	*<_weight_replicateN_>
	forvalues i=1(1)80 {
			clonevar  weight_replicate`i' =  w_fstr`i'
			label var weight_replicate`i' "Replicate weight `i'"
		}
	*</_weight_replicateN_>*/


    noi disp as res "{phang}Step 3 completed ($output_file){p_end}"


    *---------------------------------------------------------------------------
    * 4) ESCS and other calculations
    *---------------------------------------------------------------------------

    // Placeholder for other operations that we may want to include (kept in ALL-BASE)
    *<_escs_>
    *escs already available
    *</_escs_>
	
	*</_escs_quintile_>
	gen escs_quintile_read = .
	gen escs_quintile_math = .
	gen escs_quintile_scie = .
	levelsof idcntry_raw, local (c)
	foreach cc of local c {
		foreach subject in read math scie {
			_ebin escs [weight = learner_weight_`subject'] if idcntry_raw == "`cc'" , gen(q_`subject'_`cc') nquantiles(5)
			replace escs_quintile_`subject' = q_`subject'_`cc' if missing(escs_quintile_`subject')
			drop q_`subject'_`cc'
		}
	}

    noi disp as res "{phang}Step 4 completed ($output_file){p_end}"
	
	*-------------------------------------------------------------------------------
	* 5) Labelling missing values
	*-------------------------------------------------------------------------------
	labmv, mv(-97 .a -98 .b  -99 .z ) all
	qui label dir
	foreach label in `r(names)' {
		label define `label' .a "Not Applicable" .b "No Response" .z "Missing", modify
	}
	quiet ds
	foreach var in `r(varlist)' {
		local vlab : value label `var'
		if "`vlab'"==""  {
			label define l`var' .a "Not Applicable" .b "No Response"  .z "Missing", modify
			capture label val `var' l`var'
		}
		else {
		display "do nothing"
		} 
	}	


    *---------------------------------------------------------------------------
    * 6) Bring WB countrycode & harmonization thresholds, and save dtas
    *---------------------------------------------------------------------------

    // Brings World Bank countrycode from ccc_list
    // NOTE: the *assert* is intentional, please do not remove it.
    // if you run into an assert error, edit the 011_rawdata/master_countrycode_list.csv
    merge m:1 idcntry_raw using "$temp_dir/countrycode_list.dta", keep(match) assert(match using) nogen

    // Surveyid is needed to merge harmonization proficiency thresholds
    gen str surveyid = "`region'_`year'_`assessment'"
    label var surveyid "Survey ID (Region_Year_Assessment)"

    // New variable class: keyvars (not IDs, but rather key to describe the dataset)
    local keyvars "surveyid countrycode national_level"

    // Harmonization of proficiency on-the-fly, based on thresholds as CPI
    /*glad_hpro_as_cpi
    local thresholdvars "`r(thresholdvars)'"
    local resultvars    "`r(resultvars)'"*/

    // Update valuevars to include newly created harmonized vars (from the ado)
    local valuevars : list valuevars | resultvars

    // This function compresses the dataset, adds metadata passed in the arguments as chars, save GLAD_BASE.dta
    // which contains all variables, then keep only specified vars and saves GLAD.dta, and delete files in temp_dir
    /* edukit_save,  filename("$output_file") path("$output_dir") dir2delete("$temp_dir")              ///
                idvars(`idvars') varc("key `keyvars'; value `valuevars'; trait `traitvars'; sample `samplevars'") ///
                metadata("$metadata'") collection("GLAD")*/
				
	save "$output_dir/$output_file.dta", replace
	isid idcntry_raw idschool idlearner
	keep `keyvars' `idvars' `valuevars' `traitvars' `samplevars' 
	order `keyvars' `idvars' `valuevars' `traitvars' `samplevars' 
	codebook, compact
	save "$output_dir/WLD_2000_PISA_v01_M_wrk_A_GLAD.dta", replace


    noi disp as res "Creation of $output_file.dta completed"

  /*}

 /* else {
    noi disp as txt "Skipped creation of $output_file.dta (already found in clone)"
    // Still loads it, to generate documentation
    use "$output_dir/$output_file.dta", clear
  }
}