import keras
from keras.models import Sequential
from keras.layers import Dense
from keras.optimizers import Adam
from keras.utils.np_utils import to_categorical
import numpy as np
from random import randint

import matplotlib.pyplot as plt

from mygame import controlled_run
from mygame import DO_NOTHING, UP, DOWN, LEFT, RIGHT, SCREEN_WIDTH


total_number_of_games = 5
games_count = 0


x_train = np.array([])
y_train = np.array([])

max_dist = SCREEN_WIDTH

train_frequency = 10
# neural network

# ploting stuff
fig, _ = plt.subplots(ncols=1, nrows=3, figsize=(6, 6))
# fig.tight_layout()

all_scores = []
average_scores = []
average_score_rate = 10
all_x, all_y = np.array([]), np.array([])


class Wrapper(object):
    def __init__(self):
        controlled_run(self, 0)

    @staticmethod
    def visualize():
        # TODO make the graphs and what not
        pass

    def control(self, values):
        global x_train
        global y_train
        print(values)

        if values['closest_enemy'] == -1:
            return [DO_NOTHING]

        if values['old_closest_enemy'] is not -1:
            if values['score_increased'] == 1:
                x_train = np.append(
                    x_train, [values['old_closest_enemy']/max_dist])
                y_train = np.append(y_train, [values['action']])

        # TODO neural network prediction

        r = randint(0, 4)
        return [int(r)]

    def gameover(self, score):
        global games_count
        games_count += 1
        if games_count >= total_number_of_games:
            # Let's exit the program now
            return

        # Let's start another game!
        controlled_run(self, games_count)


if __name__ == '__main__':
    w = Wrapper()
