# @rel.data relative abundance of microbes
# @condition metadata for the samples
# @filter TRUE or FALSE, filter the ASVs with low prevalence and low variance
# @fixed.var fixed effect
# @levels the levels for the fixed effect
# @taxa taxonomic level for the regression
# @taxonomy only used when taxa=="ASV", convert ASV to bacterial classification
# @arcsin.transform default TRUE, transform the data by arcsine-transformation
# usage: 
# linear_regression(rel.data = deblurtax.rel[[5]],fixed.var="disease", levels =c("Control","MS"), condition = seqmeta, taxa = "Genus", taxonomy = taxonomy.deblur,out.file =  "results/QIITA/deblur_otus/Merge_tow_batches/Averaged/Linear_mixed_model/Linear_mixed_comparisons_ASV.xlsx")

linear_regression = function(rel.data, condition = seqmeta, filter =FALSE, fixed.var = c("disease_course","sex","age","bmi"), house.adjust =T,site =T,
                                            levels = c("Control","RRMS","SPMS", "PPMS"), taxa = "ASV", taxonomy = NULL, 
                                            arcsin.transform =FALSE, out.file){
  if(!require(lme4)){
    install.packages("lme4")} # need low version e.g. 1.1.16 for R3.4
  if(!require(lmerTest)){
    install.packages("lmerTest")}
  if(!require(nlme)){
    install.packages("nlme")}
  if(!require(car)){
    install.packages("car")}
  
  if(!require("gdata")){
    install.packages("gdata")}
  if(!require("car")){
    install.packages("car")
  }
  # filter the microbes with less present in 5% samples
  # TODO FIXME HACK: WHY IS ONE USING - AND ONE USING . !?!
  for (x in 1:length(colnames(rel.data)))
  {
    s = colnames(rel.data)[x]
    colnames(rel.data)[x] = paste(substring(s, 1, 5), substring(s, 7, 10), sep="-")
  }

  data = rel.data[,colnames(rel.data) %in% condition$iMSMS_ID]
  print("Number of samples:")
  print(ncol(data))

  if(filter){
    #
    # filter the microbes with small variance (citation : http://joey711.github.io/phyloseq-demo/phyloseq-demo.html)
    if(grepl("pathway|class", taxa)){
      data = data[rowSums( data > 0) >= 0.05*ncol(data),]
      data = data[apply(data,1, function(x) var(x)) > 0,]
    }else{
      data = data[apply(data,1, function(x) var(x)) >= 1e-5,]
    }
  }else{
    data = data[apply(data,1, function(x) var(x)) > 0,]
  }

  # transform the data
  if(arcsin.transform){
    data = apply(data, c(1,2), function(x) {asin(sqrt(x))})
  }
  nsamples = ncol(data)
  nbacteria = nrow(data)
  
  tdata = t(data)
  data =merge(tdata, condition, by = "row.names")
  rownames(data)= data$Row.names
  data = data[,-1]
  
  data[,fixed.var[1]] = factor(data[,fixed.var[1]], levels = levels)
  data$sex = factor(data$sex, levels=c("M","F"))
  
  data$household = factor(data$household)
 # data$diet_no_special_needs =factor(data$diet_no_special_needs)
  # change the microbiome names to linear modeling name
  taxa.table = data.frame(bacteria = colnames(data)[1:nbacteria], id = paste(taxa, 1:nbacteria,sep=""),stringsAsFactors = F)
  colnames(data)[1:nbacteria] = taxa.table$id
  
  ncols = length(unique(condition[,fixed.var[1]]))
  print(unique(condition[,fixed.var[1]]))
  print(ncols)
  result = matrix(NA, nrow = nbacteria, ncol =(ncols-1+3)*5)

  formula_right = paste(fixed.var, collapse="+")
  if (house.adjust)
    formula_right = paste(formula_right, "(1 | household)", sep="+")
  if (site)
    formula_right = paste(formula_right, "(1 | site)", sep="+")

  for(i in 1:nbacteria){
    # if (taxa.table$bacteria[i] != "Akkermansia muciniphila")
    #   next
    n = colnames(data)[i]
    formula = paste0(n, "~", formula_right)
    m = lmer(as.formula(formula), data=data)

    # if (taxa.table$bacteria[i] %in% c("Eisenbergiella tayi", "Hungatella hathewayi", "Faecalibacterium prausnitzii", "Ruthenibacterium lactatiformans", "Akkermansia muciniphila")){
    #   print("Build Top Hits Plots")
    #   print(sjPlot::tab_model(m))
    #   
    #   print(data[c(n, fixed.var[1], fixed.var[2], fixed.var[3], fixed.var[4])])
    # 
    #   for (j in 1:4){
    #     p <- ggplot(data, aes_string(x=fixed.var[j], y=n)) + #, color="household")) +
    #       geom_point() +
    #       geom_line(aes_string(y=predict(m), group="household")) +
    #       ggtitle(taxa.table$bacteria[i])
    #     print(p)
    #   }
    # }
    
    # See https://stats.stackexchange.com/questions/444917/why-are-there-large-discrepancies-between-wald-and-bootstrapped-confidence-inter
    # We likely shouldn't be using Wald test.
    
    confints_wald = confint(m,method = "Wald") 
    confints = confint(m,method = "boot") 
#    print("Comparison")
#    print(confints)
#    print(confints_wald)
    var.names = paste(fixed.var[1], levels[2:length(levels)],sep = "")
    #var.names = paste(fixed.var[1], 1:(length(levels)-1),sep = "")
    
    if(site | house.adjust){
      ncp =5
    }else{
      ncp = 4
    }
    
    if(ncols ==2){
      result[i,1:8] = c(coef(summary(m))[2:5,1],coef(summary(m))[2:5,ncp])
      result[i,9:10] = confints[rownames(confints) == var.names,]
      result[i,11:12] = confints[rownames(confints) == "sexF",]
      result[i,13:14] = confints[rownames(confints) == "age",]
      result[i,15:16] = confints[rownames(confints) == "bmi",]
    }else if(ncols ==3){
      result[i,1:10] = c(coef(summary(m))[2:6,1],coef(summary(m))[2:6,ncp])
      result[i,11:12] = confints[rownames(confints) == var.names[1],]
      result[i,13:14] = confints[rownames(confints) == var.names[2],]
      result[i,15:16] = confints[rownames(confints) == "sexF",]
      result[i,17:18] = confints[rownames(confints) == "age",]
      result[i,19:20] = confints[rownames(confints) == "bmi",]
    }else if(ncols ==4){
      result[i,1:12] = c(coef(summary(m))[2:7,1],coef(summary(m))[2:7,ncp])
      result[i,13:14] = confints[rownames(confints) == var.names[1],]
      result[i,15:16] = confints[rownames(confints) == var.names[2],]
      result[i,17:18] = confints[rownames(confints) == var.names[3],]
      result[i,19:20] = confints[rownames(confints) == "sexF",]
      result[i,21:22] = confints[rownames(confints) == "age",]
      result[i,23:24] = confints[rownames(confints) == "bmi",]
    }
  }
  
  multiple_test_correction = "fdr"
  multiple_test_correction = "bonferroni"
  
  if(ncols ==2){
    for(z in c(17:20)){
      result[,z] = p.adjust(result[,z-12], method = multiple_test_correction)
    }
  }else if(ncols ==3){
    for(z in c(21:25)){
      result[,z] = p.adjust(result[,z-15], method = multiple_test_correction)
    }
  }else if(ncols ==4){
    for(z in c(25:30)){
      result[,z] = p.adjust(result[,z-18], method = multiple_test_correction)
    }
  }
  res = data.frame(result, stringsAsFactors = F)
  colnames(res) = c(paste("Coef",c(var.names, "Female", "age", "bmi"),sep="_"), paste("Pr",c(var.names, "Female", "age", "bmi"),sep="_"),
                    apply(expand.grid(c("0.025", "0.975"),paste("Confint", c(var.names, "Female", "age", "bmi"),sep="")), 1, function(x) paste(x[2], x[1], sep=".")), 
                    paste(multiple_test_correction,c(var.names, "Female", "age", "bmi"),sep="_"))
  
  if(taxa == "ASV"){
    res$ID = taxa.table$bacteria
    res = merge(res, taxonomy, by = "ID")
  }else{
    res$ID = taxa.table$id
    res$taxonomy = taxa.table$bacteria
  }
  require(WriteXLS)
  WriteXLS(res, out.file)
  return(res)
}

