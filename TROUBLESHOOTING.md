1) For my validate function, I had trouble with the check: if its a paired sample but no R2. I initially used -n "$r2" && -s "$r2" as the check for this but that test case failed for me. When I changed it to lib_type == 'paired' && -s "$r2", it addressed these types of cases.  

2) Had trouble with the fastp and fastqc code. No error was printed and no output showed up underneath the ==stage== so I wasn't sure what was wrong. It was because those packages weren't installed so I used brew install. 

3) Same issue as about but with gatk, I needed to create a conda environment and install gatk. 

4) I had silly mistakes throughout: for example after -ERVC GVCF and before 2> I put a \ which caused no output


