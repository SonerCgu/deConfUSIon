function D=fusiRegistrationFeatures(V)
% Local anatomical contrast retains vessel/low-intensity patterns as well
% as the outer envelope. The result is an optimization feature, not anatomy.
V=single(V);valid=isfinite(V) & V>0;V(~valid)=0;
local=imgaussfilt3(V,2,'Padding','replicate');
detail=V-local;scale=imgaussfilt3(abs(detail),3,'Padding','replicate');
D=.5+.5*tanh(detail./max(.025,2*scale));D(~valid)=0;
end
