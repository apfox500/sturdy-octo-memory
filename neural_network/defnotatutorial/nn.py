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

fig, _ = plt.subplots(ncols=1, nrows=3, figsize=(6,6))
fig.tight_layout()

all_scores = []
average_scores = []
average_score_rate = 10
all_x, all_y = np.array([]), np.array([])



class Wrapper(object):
    def __init__(self):
        controlled_run(self, 0)

    @staticmethod
    def visualize():
        global all_x, all_y, average_scores, all_scores
        global x_train, y_train
        
        #Score per game
        plt.subplot(3,1,1)
        x= np.linspace(1, len(all_scores), len(all_scores))
        plt.plot(x, all_scores, 'o-', color = 'r')
        plt.xlabel("Games")
        plt.ylabel("Score")
        plt.title("Score per Game")
        
        #Training data
        plt.subplot(3, 1, 2)
        plt.scatter(x_train[y_train==0], y_train[y_train==0], color='r', label='Stay still')
        plt.scatter(x_train[y_train==1], y_train[y_train==1], color='b', label='Jump')
        plt.xlabel('Distance from the nearest enemy')
        plt.title('Training data')

        #Average score per 10 games
        plt.subplot(3, 1, 3)
        x2 = np.linspace(1, len(average_scores), len(average_scores))
        plt.plot(x2, average_scores, 'o-', color = 'b')
        plt.xlabel("Games")
        plt.ylabel("Score")
        plt.title("Average scores per 10 games")

        plt.pause(.001)

    
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

        prediction2 = model.predict(
            np.array([values['closest_enemy']/max_dist]))
        prediction = np.argmax(model.predict(
            np.array([[values['closest_enemy']]])/max_dist), axis=-1)
        r = randint(0, 100)
        random_rate = 50*(1-games_count/50)

        if r < random_rate:
            if prediction == DO_NOTHING:
                return JUMP
            else:
                return DO_NOTHING
        else:
            if prediction == JUMP:
                return JUMP
            else:
                return DO_NOTHING

    def gameover(self, score):
        global games_count
        global x_train
        global y_train
        global model

        global all_x
        global all_y
        global all_scores
        global average_scores
        global average_score_rate


        games_count += 1

        print(x_train)
        print(y_train)

        #graph stuff
        all_x = np.append(all_x, x_train)
        all_y = np.append(all_y, y_train)
        all_scores.append(score)
        Wrapper.visualize()
        
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
