# import some stuff
import numpy as np
from scipy.special import expit as activation_function
from scipy.stats import truncnorm

# Define the network
# generate random numbers within truncated normal distribution


def truncated_normal(mean=0, sd=1, low=0, upp=10):
    return truncnorm(
        (low - mean) / sd, (upp - mean) / sd, loc=mean, scale=sd)

# create the [Nnetwork] class and define its arguments
# number of nodes/neurons per lay and initialize the weight matrices


class Nnetwork:
    def __init__(self, no_of_in_nodes, no_of_out_nodes, no_of_hidden_nodes, learning_rate):
        self.no_of_in_nodes = no_of_in_nodes
        self.no_of_out_nodes = no_of_out_nodes
        self.no_of_hidden_nodes = no_of_hidden_nodes
        self.learning_rate = learning_rate
        self.create_weight_matrices()

    def create_weight_matrices(self):
        rad = 1/np.sqrt(self.no_of_in_nodes)
        X = truncated_normal(mean=0, sd=1, low=-rad, upp=rad)
        self.weights_in_hidden = X.rvs(
            (self.no_of_hidden_nodes, self.no_of_in_nodes))
        rad = 1/np.sqrt(self.no_of_hidden_nodes)
        X = truncated_normal(mean=0, sd=1, low=-rad, upp=rad)
        self.weights_hidden_out = X.rvs(
            (self.no_of_out_nodes, self.no_of_hidden_nodes))

    def train(self, input_vector, target_vector):
        pass

    def run(self, input_vector):
        # vector-> column
        input_vector = np.array(input_vector, ndmin=2).T
        input_hidden = activation_function(
            self.weights_in_hidden @ input_vector)
        output_vector = activation_function(
            self.weights_hidden_out @ input_hidden)
        return output_vector


simple_network = Nnetwork(
    no_of_in_nodes=2, no_of_out_nodes=2, no_of_hidden_nodes=4, learning_rate=.6)

print(simple_network.run([(3, 4)]))
