function out=fusiAnalysisOutputPath(in)
% Mirror acquisition folders for output without changing any source files.
out=char(in);normalized=strrep(out,'\','/');
normalized=regexprep(normalized,'(^|/)(RawData|Raw_Data_fUSI)(?=/|$)','$1AnalysedData','ignorecase');
out=strrep(normalized,'/',filesep);
end
