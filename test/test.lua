-- Unit tests and speed tests for all the modules. 
require 'gnuplot'
require 'cunn'
require 'spectralnet'
require 'Jacobian2'
matio = require 'matio'

--torch.manualSeed(123)
cutorch.setDevice(3)
torch.setdefaulttensortype('torch.FloatTensor')


local test_correctness = true
local test_crop = false
local test_bias = false
local test_interp = false
local test_interp_feat = false
local test_real = false
local test_complex_interp = false
local test_locallyConnected = false
local test_spectralconv_img = false
local test_spectralconv_img_feat = false
local test_spectralconv = false
local test_graphpool = true
local test_learnable_interp = false
local test_time = false

local mytester = torch.Tester()
local jac = nn.Jacobian
local sjac
local nntest = {}
local precision = 1e-1




function estimate_norm(M1)
   local k = M1:size(1) 
   local n = M1:size(2)
   local s = 1000
   local input = torch.rand(s,k):float()
   for i = 1,s do 
      input[i]:mul(1/input[i]:norm())
   end
   local out1 = input*M1
   local d1 = out1:norm(2,2)
   return torch.max(d1)
end


if test_learnable_interp then 
   function nntest.LearnableInterp2D()
      print('\n')
      local iH = 5
      local iW = 5
      local oH = 32
      local oW = 32
      local nInputPlanes = 2
      local nOutputPlanes = 3

      local input = torch.Tensor(nOutputPlanes, nInputPlanes, iH, iW, 2):cuda():zero()

      --local model = nn.Linear(nInputs, nOutputs)
      local model = nn.LearnableInterp2D(iH, iW, oH, oW, 'bilinear'):cuda()
      local err,jf,jb = jac.testJacobian(model, input)
      print('error on state = ' .. err)

      err,jfp,jbp = jac.testJacobianParameters(model, input, model.weight, model.gradWeight)
      print('error on weight = ' .. err)
      --mytester:assertlt(err,precision, 'error on weight')
      print('\n')
   end
end
   
--nntest.LearnableInterp2D()





if test_crop then 
   function nntest.Crop()
      print('\n')
      local iW = 8
      local iH = 8
      local rows = 2
      local cols = 2
      local batchSize = 1
      local nPlanes = 1
      model = nn.Crop(iH,iW,rows,cols,false)
      model = model:cuda()
      input = torch.CudaTensor(batchSize,nPlanes,iH,iW)
      err,jf,jb = jac.testJacobian(model, input)
      print('error on state = ' .. err)
      mytester:assertlt(err,precision, 'error on crop')
      print('\n')
   end
end


-- note, for some reason this fails with the Jacobian2 function. 
-- so does the Linear module, so it probably is ok.
-- use the default Jacobian function and change default type to double and it works.
if test_locallyConnected then 
   function nntest.LocallyConnected()
      torch.setdefaulttensortype('torch.DoubleTensor')
      print('\n')
      local nInputs = 100
      local nOutputs = 200
      local batchSize = 10
      local connTable = torch.Tensor(nOutputs, nInputs):fill(1)
      local cuts = nInputs*nOutputs/2
      -- cut some connections
      for k = 1,cuts do 
         local i = math.random(1,nInputs)
         local j = math.random(1,nOutputs)
         connTable[j][i] = 0
      end
      --local model = nn.Linear(nInputs, nOutputs)
      local model = nn.LocallyConnected(nInputs, nOutputs, connTable)
      input = torch.Tensor(batchSize, nInputs):zero()
      local err,jf,jb = jac.testJacobian(model, input)
      print('error on state = ' .. err)

      err,jfp,jbp = jac.testJacobianParameters(model, input, model.weight, model.gradWeight)
      print('error on weight = ' .. err)
      --mytester:assertlt(err,precision, 'error on weight')
      print('\n')

      local err,jfp,jbp = jac.testJacobianParameters(model, input, model.bias, model.gradBias)
      print('error on bias = ' .. err)
      --mytester:assertlt(err,precision, 'error on bias')
      torch.setdefaulttensortype('torch.FloatTensor')
      print('\n')
   end
end
   
if test_bias then
   function nntest.Bias()
      print('\n')
      local iW = 16
      local iH = 1
      local nPlanes = 3
      local batchSize = 8 
      local model = nn.Bias(nPlanes)
      model = model:cuda()
      --local input = torch.CudaTensor(batchSize, nPlanes, iH, iW)
      local input = torch.CudaTensor(batchSize, nPlanes, iW)
      local err,jf,jb = jac.testJacobian(model, input)
      print('error on state = ' .. err)
      local param,gradParam = model:parameters()
      local bias = param[1]
      local gradBias = gradParam[1]
      local err,jfp,jbp = jac.testJacobianParameters(model, input, bias, gradBias)
      print('error on bias = ' .. err)
      mytester:assertlt(err,precision, 'error on bias')
      print('\n')
   end
end

if test_complex_interp then
   function nntest.ComplexInterp()
      print('\n')
      local iW = 8
      local iH = 8
      local oW = 32
      local oH = 32
      local nInputs = 6
      local nSamples = 1
      global_debug1 = false
      global_debug2 = false
      local model = nn.ComplexInterp(iH, iW, oH, oW, 'bilinear')
      model = model:cuda()
      local input = torch.CudaTensor(nSamples,nInputs,iH,iW,2):normal()
      local err,jfc,jbc = jac.testJacobian(model, input)
      print('error on state =' .. err)
      mytester:assertlt(err,precision, 'error on state')
      print('\n')
   end
end


if test_interp then
   function nntest.Interp()
      print('\n')
      local k = 5
      local n = 32
      local nInputs = 6
      local nSamples = 2
      local model = nn.Interp(k,n,'bilinear')
      model = model:cuda()
      local input = torch.CudaTensor(nSamples,nInputs,k):normal()
      local err,jfc,jbc = jac.testJacobian(model, input)
      print('error on state =' .. err)
      mytester:assertlt(err,precision, 'error on state')
      print('\n')
   end
end


if test_interp_img then
   function nntest.InterpImage()
      print('\n')
      local iW = 8
      local iH = 8
      local oW = 32
      local oH = 32
      local nInputs = 6
      local nSamples = 2
      local model = nn.InterpImage(iH, iW, oH, oW, 'bilinear')
      model = model:cuda()
      local input = torch.CudaTensor(nSamples,nInputs,iH,iW,2):normal()
      local err,jfc,jbc = jac.testJacobian(model, input)
      print('error on state =' .. err)
      mytester:assertlt(err,precision, 'error on state')
      print('\n')
   end
end


if test_interp_feat then
   function nntest.Interp3D()
      print('\n')
      local iF = 5
      local iW = 5
      local iH = 5
      local oW = 16
      local oH = 16
      local oF = 16
      local nInputPlanes = 5
      local nOutputPlanes = 32
      local nSamples = 3
      model = nn.Interp3D(iF, iH, iW, oF, oH, oW, 'bilinear')
      model = model:cuda()
      local input = torch.CudaTensor(nSamples,iF,iH,iW,2):normal()
      local timer = torch.Timer()
      model:forward(input)
      cutorch.synchronize()
      print(timer:time().real)
      g=model.output:clone()
      timer:reset()
      model:updateGradInput(input, g)
      cutorch.synchronize()
      print(timer:time().real)

      local err,jfc,jbc = jac.testJacobian(model, input)
      print('error on state =' .. err)
      mytester:assertlt(err,precision, 'error on state')
      print('\n')
   end
end


if test_real then
   function nntest.Real()
      print('\n')
      local iW = 8
      local iH = 8
      local nInputPlanes = 3
      local batchSize = 2
      local model = nn.Real('real')
      model = model:cuda()
      local input = torch.CudaTensor(batchSize,nInputPlanes,iH,iW,2)
      local err,jf,jb = jac.testJacobian(model, input)
      print('error on state = ' .. err)
      mytester:assertlt(err, precision, 'error on state')
      print('\n')
   end
end


if test_spectralconv then
   function nntest.SpectralConvolution()
      print('\n')
      torch.manualSeed(123)
      local interpType = 'bilinear'
      local dim = 120
      local subdim = 20
      local nInputPlanes = 3
      local nOutputPlanes = 4
      local batchSize = 32






   local graphs_path = '/misc/vlgscratch3/LecunGroup/mbhenaff/spectralnet/mresgraph/'
   --local graph_name = opt.dataset .. '_spatialsim_laplacian_poolsize_' .. opt.poolsize .. '_stride_' .. opt.poolstride .. '_neighbs_' .. opt.poolneighbs .. '.th') 
   local graph_name = 'timit_laplacians.mat'
   L = matio.load(graphs_path .. graph_name)
   GFTMatrix = L.V1:float()

      --local L = torch.load('mresgraph/reuters_GFT_pool4.th')
      --local GFTMatrix = torch.eye(dim,dim)--L.V2
--      local X = torch.randn(dim,dim)
--      X = (X + X:t())/2
--      local _,GFTMatrix = torch.symeig(X,'V')
      local s = estimate_norm(GFTMatrix)
      print(s)
      --GFTMatrix = torch.eye(dim,dim)
      print(GFTMatrix:size())
      local model = nn.SpectralConvolution(batchSize,nInputPlanes,nOutputPlanes,dim, subdim, GFTMatrix:float())
      model = model:cuda()
      model:reset()
      print({model})
      local input = torch.CudaTensor(batchSize,nInputPlanes,dim):normal()
      err,jf,jb = jac.testJacobian(model, input)
      print('error on state =' .. err)
      mytester:assertlt(err,precision, 'error on state')
      
      local param,gradParam = model:parameters()
      local weight = param[1]
      local gradWeight = gradParam[1]
      err,jfp,jbp = jac.testJacobianParameters(model, input, weight, gradWeight)
      print('error on weight = ' .. err)
      mytester:assertlt(err,precision, 'error on weight')
      print('\n')

      local bias = param[2]
      local gradBias = gradParam[2]
      local err,jfp,jbp = jac.testJacobianParameters(model, input, bias, gradBias)
      print('error on bias = ' .. err)
      mytester:assertlt(err,precision, 'error on bias')

   end
end


if test_graphpool then
   function nntest.GraphMaxPool()
      torch.manualSeed(313)
      if true then
      dim = 3705
      poolsize = 8
      stride = 4
      --nClusters = math.floor(dim/stride)
      nClusters = 926
   else
      dim = 4
      poolsize = 2
      stride = 2
      --nClusters = math.floor(dim/stride)
      nClusters = 2
   end

      print(nClusters)
      local nMaps = 1
      local batchSize = 1
      for i = 1,1 do 
         local clusters
         if false then
            clusters = torch.randperm(dim)
            clusters:resize(nClusters, poolsize)
         else
            clusters = torch.Tensor(nClusters,poolsize)
            for j = 1,nClusters do 
               clusters[j]:copy(torch.randperm(dim)[{{1,poolsize}}])
            end
         end
         model = nn.GraphPooling(clusters,'avg')
         print({model})
         model = model:cuda()
         model:reset()      
         input = torch.CudaTensor(batchSize, nMaps, dim):normal()
         err,jf,jb = jac.testJacobian(model, input, -100,100)
         diff = jf:float() - jb:float()
         print('error on state = ' .. err)
         if err > precision then 
            for i = 1,diff:size(1) do 
               for j = 1,diff:size(2) do 
                  if diff[i][j] == err then 
                     print(i,j)
                  end
               end
            end
            break 
         end
      end
   end
end


if test_spectralconv_img then
   function nntest.SpectralConvolutionImage()
      print('\n')
      torch.manualSeed(123)
      torch.setdefaulttensortype('torch.FloatTensor')
      local interpType = 'spatial'
      local real = 'none'
      local iW = 16
      local iH = 16
      local nInputPlanes = 3
      local nOutputPlanes = 4
      local batchSize = 2
      local sW = 5	
      local sH = 5
      model = nn.SpectralConvolutionImage(nInputPlanes,nOutputPlanes,iH,iW,sH,sW,interpType,real)
      model = model:cuda()
      model:reset()
      model.zW = 0
      model.zH = 0
      local input = torch.CudaTensor(batchSize,nInputPlanes,iH,iW):normal()
      local err,jf,jb = jac.testJacobian(model, input)
      print('error on state =' .. err)
      mytester:assertlt(err,precision, 'error on state')
      
      local param,gradParam = model:parameters()
      local weight = param[1]
      local gradWeight = gradParam[1]
      local err,jfp,jbp = jac.testJacobianParameters(model, input, weight, gradWeight)
      print('error on weight = ' .. err)
      mytester:assertlt(err,precision, 'error on weight')

      local bias = param[2]
      local gradBias = gradParam[2]
      local err,jfp,jbp = jac.testJacobianParameters(model, input, bias, gradBias)
      print('error on bias = ' .. err)
      mytester:assertlt(err,precision, 'error on bias')


      --[[
      param,gradParam = model:parameters()
      weight = param[1]
      gradWeight = gradParam[1]
      paramType='weight'
      local err = jac.testJacobianUpdateParameters(model, input, weight)
      print('error on weight [direct update] = ' .. err)
      --mytester:assertlt(err,precision, 'error on weight [direct update]')
      --]]
      print('\n')
   end
end


if test_spectralconv_img_feat then
   function nntest.SpectralConvolutionImageAndFeatures()
      print('\n')
      torch.manualSeed(123)
      torch.setdefaulttensortype('torch.FloatTensor')
      local interpType = 'bilinear'
      local iW = 16
      local iH = 16
      local nInputPlanes = 10
      local nOutputPlanes = 10
      local batchSize = 1
      local sF = 5
      local sW = 5	
      local sH = 5
      model = nn.SpectralConvolutionImageAndFeatures(batchSize,nInputPlanes,nOutputPlanes,iH,iW,sF,sH,sW,interpType)
      model = model:cuda()
      model:reset()
      input = torch.CudaTensor(batchSize,nInputPlanes,iH,iW):normal()
      timer = torch.Timer():reset()
      --model:updateOutput(input)
      cutorch.synchronize()
      print(timer:time().real)
      g = model.output:clone()
      timer:reset()
      --model:updateGradInput(input, g)
      cutorch.synchronize()
      print(timer:time().real)
      err,jf,jb = jac.testJacobian(model, input)
      print('error on state =' .. err)
      --mytester:assertlt(err,precision, 'error on state')
      
      local param,gradParam = model:parameters()
      local weight = param[1]
      local gradWeight = gradParam[1]
      local err,jfp,jbp = jac.testJacobianParameters(model, input, weight, gradWeight)
      print('error on weight = ' .. err)
      --mytester:assertlt(err,precision, 'error on weight')
      print('\n')
   end
nntest.SpectralConvolutionImageAndFeatures()

end















function run_timing()
   print('\n')
   print('******TIMING******')
   torch.manualSeed(123)
   local ntrials = 5
   local interpType = 'bilinear'
   local iW = 32
   local iH = 32
   local nInputPlanes = 96
   local nOutputPlanes = 256
   local batchSize = 128
   local sW = 5	
   local sH = 5
   local timer = torch.Timer()
   print('image dim = ' .. iH .. ' x ' .. iH)
   print('nInputPlanes = ' .. nInputPlanes)
   print('nOutputPlanes = ' .. nOutputPlanes)
   print('batchSize = ' .. batchSize)

   if test_spectralconv_img then
      model = nn.SpectralConvolutionImage(batchSize,nInputPlanes,nOutputPlanes,iH,iW,sH,sW,interpType)
      model = model:cuda()
      input = torch.CudaTensor(batchSize,nInputPlanes,iH,iW):zero()
      gradOutput = torch.CudaTensor(batchSize,nOutputPlanes,iH,iW)
      print('------SPECTRALCONVOLUTION------')
      for i = 1,ntrials do
         print('trial' .. i)
         timer:reset()
         model:forward(input)
         cutorch.synchronize()
         print('Time for forward : ' .. timer:time().real)

         timer:reset()
         model:updateGradInput(input,gradOutput)
         cutorch.synchronize()
         print('Time for updateGradInput : ' .. timer:time().real)

         timer:reset()
         model:accGradParameters(input,gradOutput)
         cutorch.synchronize()
         print('Time for accGradParameters : ' .. timer:time().real)
      end
   end

   if test_real then
      print('\n------REAL------\n')
      model2 = nn.Real('mod'):cuda()
      input2 = model.output:clone()
      gradOutput2 = torch.CudaTensor(batchSize, nOutputPlanes, iH, iW):zero()
      for i = 1,ntrials do
         timer:reset()
         model2:updateOutput(model.output)
         cutorch.synchronize()
         print('updateOutput : ' .. timer:time().real)

         timer:reset()
         model2:updateGradInput(input2,gradOutput2)
         cutorch.synchronize()
         print('updateGradInput : ' .. timer:time().real)
      end
   end

   if test_complex_interp then
      print('\n------COMPLEX_INTERP------')
      model3 = nn.ComplexInterp(sH,sW,iH,iW,'bilinear'):cuda()
      weights = torch.CudaTensor(nOutputPlanes, nInputPlanes, sH, sW, 2)
      for i = 1,ntrials do
         timer:reset()
         model3:updateOutput(weights)
         cutorch.synchronize()
         print('updateOutput : ' .. timer:time().real)
         gradWeights = model3.output:clone()
         timer:reset()
         model3:updateGradInput(weights,gradWeights)
         cutorch.synchronize()
         print('updateGradInput : ' .. timer:time().real)
      end
   end

   if test_interp then
      print('\n------INTERP------')
      model3 = nn.Interp(sH,sW,iH,iW,'bilinear'):cuda()
      weights = torch.CudaTensor(nOutputPlanes, nInputPlanes, sH, sW, 2)
      for i = 1,ntrials do
         timer:reset()
         model3:updateOutput(weights)
         cutorch.synchronize()
         print('updateOutput : ' .. timer:time().real)
         gradWeights = model3.output:clone()
         timer:reset()
         model3:updateGradInput(weights,gradWeights)
         cutorch.synchronize()
         print('updateGradInput : ' .. timer:time().real)
      end
   end

   if test_crop then
      print('\n--------CROP-------------')
      input = torch.CudaTensor(batchSize,nInputPlanes,iH,iW):zero()
      gradOutput = torch.CudaTensor(batchSize,nOutputPlanes,iH,iW)
      model4 = nn.Crop(iH,iW,2,2,false):cuda()
      for i = 1,ntrials do
         timer:reset()
         model4:updateOutput(input)
         cutorch.synchronize()
         print('updateOutput : ' .. timer:time().real)
         gradOutput = model4.output:clone()
         timer:reset()
         model4:updateGradInput(input, gradOutput)
         print('updateGradInput : ' .. timer:time().real)
      end
   end
end

mytester:add(nntest)
if test_correctness then
   mytester:run()
end

if test_time then 
   run_timing()
end


