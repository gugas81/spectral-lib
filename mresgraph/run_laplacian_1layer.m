%this script generates the GFT matrix and pools for 1 layer
kernel = 'gauss';
poolsize = 32;
poolstride = 16;
do_pooling = 0;
alpha = 0.01;


for d = 3:3
dataset = ['merck' num2str(d) 'fc']
%dataset = 'reuters';
if 1
                                %  clear all
  close all
  data = loadData(dataset);
  data=data';

  if strcmp(dataset,'timit')
    data=reshape(data,120,numel(data)/120);
    end
    fprintf('data ready \n')

    if strcmp(kernel,'PCA')
      K1 = data*data';
      [V1,ev] = eig(K1);

    elseif strcmp(kernel,'gauss')
      %%2 Gaussian Kernel
      fprintf('computing kernel...');
      K0 = kernelization(data);
                                %adjust sparsity level 
      [K0s, Is]=sort(K0,2,'ascend');
      loc=round(alpha*size(K0s,2));
      sigma = sqrt( mean(K0s(:,loc)));
      K1=exp(-K0/sigma^2);
      fprintf('done\n');
                                % compute laplacian
      D = diag(sum(K1).^(-1/2));
      L = eye(size(K1,1)) - D * K1 * D;
      L = (L+L')/2;
      [V1,ev]=eig(L);
                                %construct the neighbordhoods
      NN=zeros(size(L));
      for i=1:size(K0s,1)
        ind = find(K0(i,:) < sigma^2);
        NN(i,ind)=1;
      end

      elseif strcmp(kernel,'gausslocal')
      %%2 Gaussian Kernel
      fprintf('computing kernel...');
      K0 = kernelization(data);
                                %adjust sparsity level 
      [K0s, Is]=sort(K0,2,'ascend');
      loc=round(alpha*size(K0s,2));
%      sigma = sqrt( mean(K0s(:,loc)));
      sigmas = sqrt(abs(K0s(:,loc)));
      K1 = exp(-((K0) ./ (sigmas*sigmas')));
      %K1=exp(-K0/sigma^2);
      fprintf('done\n');
                                % compute laplacian
      D = diag(max(0.000001,sum(K1)).^(-1/2));
      L = eye(size(K1,1)) - D * K1 * D;
      L = (L+L')/2;
      [V1,ev]=eig(L);
                                %construct the neighbordhoods
      NN=zeros(size(L));
      for i=1:size(K0s,1)
        ind = find(K0(i,:) < sigma^2);
        NN(i,ind)=1;
      end
        

    elseif strcmp(kernel,'random')
      LW = randn(size(data,1));
      [V1,~,~]=svd(LW);
  end

end


% Get pools
unix(['mkdir -p '  '/misc/vlgscratch3/LecunGroup/mbhenaff/spectralnet/mresgraph/alpha_' num2str(alpha)]);
if do_pooling 
  [V,pools] = ms_spectral_clustering(K1,K1,1,1/poolstride,poolsize);
  V1=V{1};
  save(['/misc/vlgscratch3/LecunGroup/mbhenaff/spectralnet/mresgraph/alpha_' num2str(alpha) '/' dataset '_laplacian_' kernel '_poolsize_' num2str(poolsize) '_poolstride_' num2str(poolstride) '.mat'],'V1','L','pools','NN');
else
  save(['/misc/vlgscratch3/LecunGroup/mbhenaff/spectralnet/mresgraph/alpha_' num2str(alpha) '/' dataset '_laplacian_' kernel '.mat'],'V1','L','NN');
end 
end



