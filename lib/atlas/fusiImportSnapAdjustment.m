function [M,report]=fusiImportSnapAdjustment(file,proposalFile,currentM)
% ITK-SNAP fixed->moving physical transform on the ALREADY ALIGNED review
% overlay. Compose its inverse with the native->atlas proposal, once only.
if isstruct(proposalFile),p=proposalFile;proposalFile='In-memory ITK-SNAP review session';
elseif endsWith(proposalFile,'.json','IgnoreCase',true),p=jsondecode(fileread(proposalFile));
else,p=load(proposalFile,'M','spacingUm');end
if ~isequal(size(p.M),[4 4]) || norm(p.M-currentM,'fro')>1e-7
    error('deConfUSIon:SnapStale','MATLAB alignment changed after this ITK-SNAP review. Open a new review before importing.');
end
text=fileread(file);format='ITK LPS affine';
if contains(text,'Transform:')
    types=regexp(text,'(?m)^Transform:\s*(\S+)','tokens');
    if numel(types)~=1 || isempty(regexp(types{1}{1},'^(AffineTransform|MatrixOffsetTransformBase)_double_3_3$','once'))
        error('deConfUSIon:SnapFormat','Save ONE affine transform in ITK text (.tfm/.txt) or Convert3D 4x4 RAS text format.');
    end
    values=regexp(text,'(?m)^Parameters:\s*([^\r\n]+)','tokens','once');
    center=regexp(text,'(?m)^FixedParameters:\s*([^\r\n]+)','tokens','once');
    if isempty(values) || isempty(center),error('deConfUSIon:SnapFormat','Missing ITK affine parameters or center.');end
    v=sscanf(values{1},'%f');c=sscanf(center{1},'%f');
    if numel(v)~=12 || numel(c)~=3,error('deConfUSIon:SnapFormat','Expected 12 affine and 3 center parameters.');end
    A=reshape(v(1:9),3,3)';H=[A v(10:12)+c-A*c;0 0 0 1];
else
    values=sscanf(text,'%f');
    if numel(values)~=16,error('deConfUSIon:SnapFormat','Expected a 4x4 Convert3D RAS text matrix. Binary transforms are unsupported.');end
    H=reshape(values,4,4)';flip=diag([-1 -1 1 1]);H=flip*H*flip;
    format='Convert3D RAS affine';
end
if any(~isfinite(H(:))) || norm(H(4,:)-[0 0 0 1])>1e-8 || det(H(1:3,1:3))<=0 || rcond(H)<1e-12
    error('deConfUSIon:SnapFormat','Transform is invalid, singular or reflects the brain.');
end
spacing=double(p.spacingUm(:)')/1000;
% Review NIfTI axes [LR AP DV], with RAS directions [+ - -]. ITK uses LPS;
% index zero is physical origin. MATLAB affine3d uses one-based [DV AP LR].
C=[0 0 -spacing(2) 0;0 spacing(1) 0 0;-spacing(3) 0 0 0;spacing(3) -spacing(1) spacing(2) 1];
delta=(C/H')/C;M=p.M*delta;M(:,4)=[0;0;0;1];
scales=svd(delta(1:3,1:3));
if min(scales)<.5 || max(scales)>2
    error('deConfUSIon:SnapFormat','Manual adjustment has implausible scale. Check units and selected moving layer.');
end
report=struct('engine','ITK-SNAP manual adjustment','matrix',M,'baseMatrix',p.M, ...
    'adjustmentMatrix',delta,'transformFile',file,'reviewProposalFile',proposalFile, ...
    'format',format,'reviewRequired',true,'created',datestr(now,30), ...
    'method','Inverse of fixed-to-moving review-space physical transform composed with native-to-atlas proposal.');
end
