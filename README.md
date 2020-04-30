# THB-MCMC
A transdimensional hierarchical Bayesian reversible jump Markov chain Monte Carlo method for active source seismic refraction inversions

THB inversion utilizes a reversible-jump Markov-chain Monte Carlo (MCMC) algorithm to create a set of velocity models that best describe the observed data (Bodin et al., 2012; Burdick and Lekic, 2017). Using this method, one analyzes the posterior probability assigned to every given velocity model, rather than producing one single best-fit model (Burdick and Lekic, 2017). The result of this process is a collection of possible solutions, in which solutions with a higher likelihood of describing the data are represented at a higher likelihood (Burdick and Lekic, 2017). Because the results consist of multiple possible velocity structures, it is easier to understand both the range of plausible solutions and the uncertainty associated with the velocity profiles (Burdick and Lekic, 2017).
As mentioned in the main text, MCMC involves the following steps. First, create a new velocity model by randomly selecting a parameter to vary. The initial velocity model is set up by user-defined parameter limits called prior sigmas. These parameters construct a velocity structure in terms of horizontal layers and hinge points, which allow for lateral heterogeneity within a layer (Burdick and Lekic, 2017). Once the initial model is generated, one of five functions is selected to vary the parameters and create a new model: change the velocity, move a cell, create a new cell, delete a cell, or change the noise parameter (Burdick and Lekic, 2017; Bodin et al., 2012). The MCMC algorithm selects parameter values from within a normal distribution of user-defined values, representing the amount the program is allowed to vary a parameter by, called proposal sigmas.
Second, the method calculates the posterior probability given estimated travel times for the new velocity profile. Travel times for the proposed model are generated using the fast-marching method, described by Sethian (1995). Posterior probability is calculated to reflect the difference between modeled and observed travel times (Bodin et al., 2012). Finally, the program decides to accept or reject the model based on its effect on the posterior probability, according to the Metropolis-Hastings algorithm (Burdick and Lekic, 2017). The new model is either accepted and added to the current model or rejected and removed. After one thousand iterations, the current model is saved to an ensemble. Earlier models are predicted to have the highest uncertainty, therefore models produced before a user-defined burn-in period are discarded. After many iterations, model misfit will stabilize, at which point standard deviation of ensemble velocity can be calculated to indicate areas where the velocity profile has greater uncertainty. Readers interested in more details about the inversion method can refer to Bodin et al. (2012) and Burdick and Lekic (2017).
This tutorial provides an overview of the THB MCMC algorithm, detailed explanation of the model parameters and setup, execution of the program with an example, and figures produced by the program. 

How to cite this program:


References
THB manual
Bodin
Burdick and Lekic
Gabriel Peyre (2020). Toolbox Fast Marching (https://www.mathworks.com/matlabcentral/fileexchange/6110-toolbox-fast-marching), MATLAB Central File Exchange. Retrieved April 4, 2020.
