function report = fusiLightSuiteDependencies(cfg)
% Check usable requirements per workflow; do not install licensed toolboxes.
if nargin<1,cfg=fusiLightSuiteConfig();end
rows = cell(0,4);
products = {'Computer Vision Toolbox','Image Processing Toolbox', ...
    'Optimization Toolbox','Parallel Computing Toolbox','Statistics and Machine Learning Toolbox'};
features={'Video_and_Image_Blockset','image_toolbox','Optimization_Toolbox','Distrib_Computing_Toolbox','Statistics_Toolbox'};
installed=ver;
rows(end+1,:)={'MATLAB R2022b or newer',~verLessThan('matlab','9.13'),'all',version};
for k=1:numel(products)
    available=any(strcmp(products{k},{installed.Name}))&&license('test',features{k});
    rows(end+1,:)={products{k},available,'all',['Installed product and license feature: ' features{k}]}; %#ok<AGROW>
end
items = { 'LightSuite source', fullfile(cfg.lightSuite,'src','fusi','setupFusiOptions.m'),'all'; ...
    'matlab_elastix',fullfile(cfg.matlabElastix,'code','invertElastixTransformCP.m'),'all'; ...
    'yamlmatlab',fullfile(cfg.yamlMatlab,'+yaml','ReadYaml.m'),'all'; ...
    'BCPD executable',fullfile(cfg.bcpd,'bcpd.exe'),'histology'; ...
    'Elastix 5.1.0',fullfile(cfg.elastixBin,'elastix.exe'),'all'; ...
    'Transformix 5.1.0',fullfile(cfg.elastixBin,'transformix.exe'),'all'; ...
    'Vascular template',fullfile(cfg.vascularAtlas,'vessel_atlas_template.nii.gz'),'fusi'; ...
    'Vascular labels',fullfile(cfg.vascularAtlas,'vessel_atlas_annotation.nii.gz'),'fusi'; ...
    'Allen parcellation table',fullfile(cfg.allenAtlas,'parcellation_to_parcellation_term_membership.csv'),'all'; ...
    'Allen 10 um template',fullfile(cfg.allenAtlas,'average_template_10.nii.gz'),'histology'; ...
    'Allen 10 um labels',fullfile(cfg.allenAtlas,'annotation_10.nii.gz'),'histology'; ...
    'BioformatsImage (CZI only)',fullfile(cfg.bioformats,'BioformatsImage.m'),'czi'; ...
    'OME Bio-Formats (CZI only)',fullfile(cfg.bfmatlab,'bfopen.m'),'czi'};
for k=1:size(items,1),rows(end+1,:)={items{k,1},isfile(items{k,2}),items{k,3},items{k,2}};end %#ok<AGROW>
T=cell2table(rows,'VariableNames',{'Requirement','Available','Workflow','Details'});
T.Available=logical(T.Available);
report=struct('table',T,'fusiReady',all(T.Available(ismember(T.Workflow,{'all','fusi'}))), ...
    'histologyReady',all(T.Available(ismember(T.Workflow,{'all','histology'}))), ...
    'cziReady',all(T.Available(ismember(T.Workflow,{'all','histology','czi'}))), ...
    'config',cfg,'elastixVersion','','transformixVersion','','sourceCommit','');
if isfile(fullfile(cfg.elastixBin,'elastix.exe'))
    [status,out]=system(sprintf('"%s" --version',fullfile(cfg.elastixBin,'elastix.exe')));
    report.elastixVersion=strtrim(out);
    if status~=0 || ~contains(out,'5.1.0')
        report.fusiReady=false;report.histologyReady=false;report.cziReady=false;
    end
end
if isfile(fullfile(cfg.elastixBin,'transformix.exe'))
    [status,out]=system(sprintf('"%s" --version',fullfile(cfg.elastixBin,'transformix.exe')));
    report.transformixVersion=strtrim(out);
    if status~=0 || ~contains(out,'5.1.0')
        report.fusiReady=false;report.histologyReady=false;report.cziReady=false;
    end
end
if isfolder(fullfile(cfg.lightSuite,'.git'))
    [status,out]=system(sprintf('git -C "%s" rev-parse HEAD',cfg.lightSuite));
    if status==0,report.sourceCommit=strtrim(out);end
end
if ~isempty(report.sourceCommit) && ~strcmp(report.sourceCommit,cfg.pinnedCommit)
    report.fusiReady=false;report.histologyReady=false;report.cziReady=false;
end
if nargout==0,disp(T);fprintf('fUSI ready: %d | TIFF histology ready: %d | CZI ready: %d\n',report.fusiReady,report.histologyReady,report.cziReady);end
end
