function [next,q]=fusiVolumeSequenceData(data,q,index,progress,maskFile)
% Load one power scan, compute its selected PSC baseline, retain display grid.
if nargin<4,progress=@(~,~)[];end
if nargin<5,maskFile='';end
assert(~data.inputIsPSC,'deConfUSIon:VolumeSequencePower','Open raw/preprocessed power data to change scan baselines.');
source=data.par.scanSequence.scans{data.par.scanSequence.active};target=q.scans{index};
power=data.I;if isfield(data,'nativePower'),power=data.nativePower;end
[q,b]=fusiScanSequence('prepare',q,data.baseline,power,data.TR,data.par,progress);
originalMemory=q.scans{index}.memoryPower;
if strcmp(source.key,target.key),q.scans{index}.memoryPower=power;end
[proc,b,newPar,power]=fusiScanSequence('load',q,index,b,data.par,progress);
q=newPar.scanSequence;q.scans{index}.memoryPower=originalMemory;newPar.scanSequence=q;
next=data;next.par=newPar;next.nativePower=power;next.baseline=b;
next.TR=target.TR;next.interpol=1;next.frame=1;next.label=target.label;
anchor=source;if isfield(data,'displayDescriptor'),anchor=data.displayDescriptor;end
next.displayDescriptor=anchor;
mapping=[];if isfield(data,'scanMapping'),mapping=data.scanMapping;end
if data.transformed
 assert(~isempty(mapping),'deConfUSIon:VolumeSequenceMapping','The registered view needs its saved native-to-atlas mapping. Reopen 3D from Video.');
 mapping=scmRebaseROIMapping(mapping,source,target);next.scanMapping=mapping;
 shape=size(data.PSC,1:3);next.PSC=scmWarpMappedSeries(proc.PSC,mapping,shape);
 next.I=scmWarpMappedSeries(power,mapping,shape);
 for name={'atlasVoxelSizeYXZUm','atlasOutputArrayOrder','nativeColumnOneSide'}
  if isfield(data.par,name{1}),next.par.(name{1})=data.par.(name{1});end
 end
else
 next.PSC=fusiScanSequence('mapSeries',proc.PSC,target,anchor);
 next.I=fusiScanSequence('mapSeries',power,target,anchor);
end
% Keep anatomy by default; masks stay on the retained display grid.
mode='keep';if isfield(q,'underlayMode'),mode=q.underlayMode;end
if data.transformed&&fusiScanSequence('shareAtlas',q),mode='keep';end
if strcmp(mode,'default')
 bg=proc.bg;if data.transformed,bg=scmWarpMappedSeries(bg,mapping,size(data.PSC,1:3));
 else,bg=fusiScanSequence('mapVolume',bg,target,anchor);end
 next.underlay=bg;next.underlayProcessed=false;next.underlayLabel='Selected scan Doppler';
elseif strcmp(mode,'mask')
 assert(isfile(maskFile),'deConfUSIon:VolumeSequenceUnderlay','Select this scan''s Mask Editor bundle.');
 B=scmReadMaskEditorBundle(load(maskFile));assert(~isempty(B),'deConfUSIon:VolumeSequenceUnderlay','Choose a saved Mask Editor bundle.');
 if data.transformed
  ctx=struct('sizeYXZ',size(data.PSC,1:3),'nativeSizeYXZ',target.spatialSize, ...
   'mapping',mapping,'isAtlasWarped',true);B=scmReadMaskEditorBundle('align',B,ctx);
 else
  B.image=fusiScanSequence('mapVolume',B.image,target,anchor);
  if ~isempty(B.includeMask),B.includeMask=fusiScanSequence('mapVolume',B.includeMask,target,anchor);end
 end
 next.underlay=B.image;next.underlayProcessed=B.isProcessed;next.underlayLabel=maskFile;
 if ~isempty(B.includeMask),next.mask=B.includeMask;next.maskIsInclude=true;end
end
next.par.scmSizeYXZ=size(next.PSC,1:3);
nativeData=next;nativeData.I=power;nativeData.transformed=false;
[u,next.baselineInfo]=fusiVolumeBaseline(nativeData);
if ~isempty(u)
 if data.transformed,u=scmWarpMappedSeries(u,mapping,size(data.PSC,1:3));
 else,u=fusiScanSequence('mapVolume',u,target,anchor);end
end
next.baselineUnderlay=u;
end
