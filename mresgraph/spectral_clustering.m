function [V, anchors, clusters] = spectral_clustering(W, n, maxclustsize)

%1) build the spectrum
D = diag(sum(W).^(-1/2));
L = eye(size(W,1)) - D * W * D;
L = (L + L')/2;
[ee,ev]=eig(L);
V=ee;
X=ee(:,end-n+1:end);

%renormalize rows
X=X./repmat(sqrt(sum(X.^2,2)),1,size(X,2));

%2) kmeans using balanced clusters
[outlabels, outm]=litekmeans(X',n,1,maxclustsize);

cross = kernelizationbis(X,outm');

[~,anchors] = min(cross); 

for i=1:size(outm,2)
  clusters{i} = find(outlabels==i);
  len(i) = length(clusters{i});
end
fprintf('cluster sizes in [%d, %d] ave is %f \n', min(len), max(len), mean(len))


