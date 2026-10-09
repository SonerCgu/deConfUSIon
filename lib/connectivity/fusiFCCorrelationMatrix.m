function [R,valid]=fusiFCCorrelationMatrix(X)
% Pearson correlations for complete, nonconstant time-course columns.
% Undefined correlations remain NaN, including their diagonal entries.
X=double(X);n=size(X,2);R=nan(n,n);valid=false(1,n);
if size(X,1)<2 || n==0,return;end
complete=all(isfinite(X),1);
C=bsxfun(@minus,X(:,complete),mean(X(:,complete),1));
energy=sum(C.^2,1);
indices=find(complete);valid(indices)=isfinite(energy)&energy>0;
C=C(:,isfinite(energy)&energy>0);
norms=sqrt(sum(C.^2,1));C=bsxfun(@rdivide,C,norms);
M=max(-1,min(1,C'*C));M(1:size(M,1)+1:end)=1;
R(valid,valid)=M;
end
