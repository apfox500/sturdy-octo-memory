import keras
from keras.models import Sequential
from keras.layers import Dense
from keras.optimizers import Adam
from keras.utils.np_utils import to_categorical
import numpy as np
from random import randint

import matplotlib.pyplot as plt

from game import controlled_run
from game import DO_NOTHING
from game import JUMP

total_number_of_games = 100
games_count = 0


x_train = np.array([])
y_train = np.array([])

max_dist = 1000

train_frequency = 10

# neural network:
model = Sequential()
model.add(Dense(1, input_dim=1, activation="sigmoid"))
model.add(Dense(2, activation="softmax"))
model.compile(Adam(lr=.1), loss='categorical_crossentropy',
              metrics=['accuracy'])

plt.subplots(ncols=1, nrows=3)

class Wrapper(object):
    def __init__(self):
        controlled_run(self, 0)

    def control(self, values):
        global x_train
        global y_train
        global model
        print(values)
        if values['closest_enemy'] == -1:
            return DO_NOTHING

        if values['old_closest_enemy'] is not -1:
            if values['score_increased'] == 1:
                x_train = np.append(
                    x_train, [values['old_closest_enemy']/max_dist])
                y_train = np.append(y_train, [values['action']])

        prediction2 = model.predict(np.array([values'closest_enemy']/max_d))
        prediction = np.argmax(model.predict(
            np.array([[values['closest_enemy']]])/max_dist), axis=-1)
        return prediction

    def gameover(self, score):
        global games_count
        global x_train
        global y_train
        global model

        games_count += 1

        print(x_train)
        print(y_train)
        if games_count is not 0 and games_count % train_frequency is 0:
            y_train_cat = to_categorical(y_train, num_classes=2)
            model.fit(x_train, y_train_cat, epochs=50, verbose=1, shuffle=1)
            x_train = np.array([])
            y_train = np.array([])

        if games_count >= total_number_of_games:
            # Let's exit the program now
            return
        controlled_run(self, games_count)


if __name__ == '__main__':
    w = Wrapper()
