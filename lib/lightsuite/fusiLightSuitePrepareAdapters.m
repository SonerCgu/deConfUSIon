function folder=fusiLightSuitePrepareAdapters(cfg)
% Generate narrowly patched copies; downloaded source and licenses stay intact.
% These copies use the installed upstream implementation and its license.
folder=fullfile(cfg.externalRoot,'deConfUSIonAdapters','fileio-progress-v1');
if ~isfolder(folder),mkdir(folder);end
source=fullfile(cfg.matlabElastix,'code','elastix.m');
if ~isfile(source),return;end
text=fileread(source);
text=patch(text,'mhd_write(movingImage,movingFname, p.Results.movingscale);', ...
    'mhd_write(movingImage,fullfile(outputDir,movingFname), p.Results.movingscale);');
text=patch(text,'mhd_write(fixedImage,targetFname, p.Results.fixedscale);', ...
    'mhd_write(fixedImage,fullfile(outputDir,targetFname), p.Results.fixedscale);');
text=regexprep(text,'if ~strcmp\(outputDir,''\.''\)[^\r\n]*\r?\n\s*if ~movefile\(\[(movingFname|targetFname),''\.\*''\],outputDir\); error\(''Can''''t move files''\), end\r?\n\s*end', ...
    '% deConfUSIon: image pair was written directly into outputDir.');
assert(~contains(text,'error(''Can''''t move files'')'), ...
    'deConfUSIon:LightSuiteAdapterVersion','Unsupported matlab_elastix file layout. Keep the pinned dependency revision.');
text=patch(text,'[status,result]=system(CMD);','[status,result]=fusiLightSuiteRunElastix(CMD,outputDir,paramFname);');
writeAdapter(folder,'elastix.m',text);
source=fullfile(cfg.lightSuite,'src','registration','multiobjRegistrationFusi.m');
text=fileread(source);
text=patch(text,'[~,~,affelastix] = performMultObjAffineRegistration', ...
    sprintf('fusiLightSuiteFitProgress(''stage'',''1/4 Affine optimization'');\n[~,~,affelastix] = performMultObjAffineRegistration'));
text=patch(text,'[reg, ~, bspltformpath, pathbspl] = fusiMultObjBsplineRegistration', ...
    sprintf('fusiLightSuiteFitProgress(''stage'',''2/4 B-spline optimization'');\n[reg, ~, bspltformpath, pathbspl] = fusiMultObjBsplineRegistration'));
text=patch(text,'cpaffine        = tform_aff.transformPointsForward(cptsatlas);', ...
    sprintf('cpaffine        = tform_aff.transformPointsForward(cptsatlas);\nfusiLightSuiteFitProgress(''stage'',''1/4 Affine overlays and diagnostic images'');'));
text=patch(text,'avreg = transformAnnotationVolume(bspltformpath, avaffine, opts.registres);', ...
    sprintf('fusiLightSuiteFitProgress(''stage'',''2/4 Nonlinear overlays and diagnostic images'');\navreg = transformAnnotationVolume(bspltformpath, avaffine, opts.registres);'));
text=patch(text,'invstats   = invertElastixTransformCP', ...
    sprintf('fusiLightSuiteFitProgress(''stage'',''3/4 Inverse transform optimization'');\ninvstats   = invertElastixTransformCP'));
writeAdapter(folder,'multiobjRegistrationFusi.m',text);
end
function value=patch(value,old,new)
assert(numel(strfind(value,old))==1,'deConfUSIon:LightSuiteAdapterVersion', ...
    'Expected pinned dependency code was not found. Check the LightSuite dependency versions.');
value=strrep(value,old,new);
end
function writeAdapter(folder,name,text)
target=fullfile(folder,name);
text=['% deConfUSIon runtime adapter; upstream source and license remain in the sibling dependency folder.' newline text];
if isfile(target)&&strcmp(fileread(target),text),return;end
temporary=[tempname(folder) '.m'];fid=fopen(temporary,'w');
assert(fid>=0,'Cannot write LightSuite compatibility adapter in %s.',folder);
clean=onCleanup(@()fclose(fid));fwrite(fid,text,'char');clear clean;
[ok,message]=movefile(temporary,target,'f');assert(ok,'Cannot save LightSuite adapter: %s',message);
end
