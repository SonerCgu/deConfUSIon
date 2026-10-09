function M=fusiCopyVideoMask(M,slice,frame,allSlices)
% Copy the current spatial mask; preserve its include/exclude interpretation.
validateattributes(slice,{'numeric'},{'scalar','integer','>=',1,'<=',size(M,3)});
validateattributes(frame,{'numeric'},{'scalar','integer','>=',1,'<=',size(M,4)});
source=M(:,:,slice,frame);
if allSlices
    M=repmat(source,[1 1 size(M,3) size(M,4)]);
else
    M(:,:,slice,:)=repmat(source,[1 1 1 size(M,4)]);
end
end
