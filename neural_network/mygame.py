import copy
import pygame
from pygame.locals import(RLEACCEL, K_UP, K_DOWN, K_LEFT,
                          K_RIGHT, K_ESCAPE, KEYDOWN, QUIT, K_w, K_s, K_i)
import random

# constants
SCREEN_WIDTH = 1200
SCREEN_HEIGHT = 800
MAXFPS = 150
SKYBLUE = (135, 206, 250)
DO_NOTHING = 0
UP = 1
DOWN = 2
RIGHT = 3
LEFT = 4

clock_tick = 30
frames = 0
score = 0
gameEnded = False
controlled = False
action_counter = 0
invincible = False


class Player(pygame.sprite.Sprite):
    global clock_tick

    def __init__(self):
        super(Player, self).__init__()
        self.surf = pygame.image.load("jet.png").convert()
        self.surf.set_colorkey((255, 255, 255), RLEACCEL)
        self.rect = self.surf.get_rect()

    def userUpdate(self, pressed_keys):
        global clock_tick, invincible

        if pressed_keys[K_UP]:
            self.rect.move_ip(0, -5)
            # move_up_sound.play()
        if pressed_keys[K_DOWN]:
            self.rect.move_ip(0, 5)
            # move_down_sound.play()
        if pressed_keys[K_LEFT]:
            self.rect.move_ip(-5, 0)
        if pressed_keys[K_RIGHT]:
            self.rect.move_ip(5, 0)
        if pressed_keys[K_w] and clock_tick < MAXFPS:
            clock_tick += 5
        if pressed_keys[K_s] and clock_tick > 5:
            clock_tick -= 5
        if pressed_keys[K_i]:
            invincible = not invincible

        # make sure youre on the screen
        if self.rect.left < 0:
            self.rect.left = 0
        if self.rect.right > SCREEN_WIDTH:
            self.rect.right = SCREEN_WIDTH
        if self.rect.top <= 0:
            self.rect.top = 0
        if self.rect.bottom >= SCREEN_HEIGHT:
            self.rect.bottom = SCREEN_HEIGHT

    def compUpdate(self, actions):
        for action in actions:
            if action == UP:
                self.rect.move_ip(0, -5)
            elif action == DOWN:
                self.rect.move_ip(0, 5)
                # move_down_sound.play()
            elif action == LEFT:
                self.rect.move_ip(-5, 0)
            elif action == RIGHT:
                self.rect.move_ip(5, 0)
            elif action == DO_NOTHING:
                pass

        # make sure youre on the screen
        if self.rect.left < 0:
            self.rect.left = 0
        if self.rect.right > SCREEN_WIDTH:
            self.rect.right = SCREEN_WIDTH
        if self.rect.top <= 0:
            self.rect.top = 0
        if self.rect.bottom >= SCREEN_HEIGHT:
            self.rect.bottom = SCREEN_HEIGHT


class Enemy(pygame.sprite.Sprite):
    def __init__(self):
        super(Enemy, self).__init__()
        self.surf = pygame.image.load("missile.png").convert()
        self.surf.set_colorkey((255, 255, 255), RLEACCEL)
        self.rect = self.surf.get_rect(
            center=(random.randint(
                SCREEN_WIDTH+20, SCREEN_WIDTH+100), random.randint(0, SCREEN_HEIGHT),
            ),
        )
        self.speed = random.randint(5, 20)

    def update(self):
        self.rect.move_ip(-self.speed, 0)
        if self.rect.right < 0:
            self.kill()


class Cloud(pygame.sprite.Sprite):
    def __init__(self):
        super(Cloud, self).__init__()
        self.surf = pygame.image.load("cloud.png").convert()
        self.surf.set_colorkey((0, 0, 0), RLEACCEL)
        self.rect = self.surf.get_rect(
            center=(
                random.randint(SCREEN_WIDTH + 20, SCREEN_WIDTH + 100),
                random.randint(0, SCREEN_HEIGHT),
            )
        )

    def update(self):
        self.rect.move_ip(-5, 0)
        if self.rect.right < 0:
            self.kill()


def update(display,  player, pressed_keys, comp=False):
    global score, clock_tick, invincible
    display.fill((135, 206, 250))

    myfont = pygame.font.SysFont('Comic Sans MS', 30)
    scoreText = myfont.render(
        ("Score: "+str(score)), False, (0, 0, 0), SKYBLUE)
    display.blit(scoreText, (0, SCREEN_HEIGHT-45))
    fps = myfont.render((str(clock_tick)+" fps"), False,
                        (0, 0, 0), (135, 206, 250))
    display.blit(fps, (SCREEN_WIDTH-fps.get_width()-15, SCREEN_HEIGHT-45))

    invincibleText = myfont.render(
        "Invincible", False, (0, 206, 250), (135, 206, 250))
    if invincible:
        display.blit(invincibleText, (SCREEN_WIDTH/2 -
                     invincibleText.get_width()/2, SCREEN_HEIGHT-45))
    if not comp:
        player.userUpdate(pressed_keys)
    enemies.update()
    clouds.update()


def run():
    global frames, score, gameEnded, player, enemies, clouds, all_sprites

    global clock_tick

    pygame.init()
    screen = pygame.display.set_mode([SCREEN_WIDTH, SCREEN_HEIGHT])
    score = 0
    gameEnded = False
    # generating npcs
    # ADDENEMY = pygame.USEREVENT + 1
    # pygame.time.set_timer(ADDENEMY, 250)
    # ADDCLOUD = pygame.USEREVENT+2
    # pygame.time.set_timer(ADDCLOUD, 1000)

    # sprites and groups
    player = Player()
    enemies = pygame.sprite.Group()
    clouds = pygame.sprite.Group()
    all_sprites = pygame.sprite.Group()
    all_sprites.add(player)

    # set up a clock
    clock = pygame.time.Clock()
    clock_tick = 30

    # sound
    # pygame.mixer.music.load("Apoxode_-_Electric_1.mp3")
    # pygame.mixer.music.play(loops=-1)
    # move_up_sound = pygame.mixer.Sound("Rising_putter.ogg")
    # move_down_sound = pygame.mixer.Sound("Falling_putter.ogg")
    # collision_sound = pygame.mixer.Sound("Collision.ogg")

    # game loop

    while gameEnded is not True:
        for event in pygame.event.get():
            if event.type == KEYDOWN:
                # Escape key to quit
                if event.key == K_ESCAPE:
                    gameEnded = True

                # Quit button to quit
            elif event.type == QUIT:
                gameEnded = True

            # elif event.type == ADDENEMY:
            #     new_enemy = Enemy()
            #     enemies.add(new_enemy)
            #     all_sprites.add(new_enemy)

            # elif event.type == ADDCLOUD:
            #     new_cloud = Cloud()
            #     clouds.add(new_cloud)
            #     all_sprites.add(new_cloud)

        # update positions

        pressed_keys = pygame.key.get_pressed()
        update(screen, player, pressed_keys)

        # actually drawing things
        # screen setup

        # draw sprites
        for entity in all_sprites:
            screen.blit(entity.surf, entity.rect)

        # collision detection
        if pygame.sprite.spritecollideany(player, enemies) and not invincible:
            player.kill()
            # move_up_sound.stop()
            # move_down_sound.stop()
            # collision_sound.play()
            gameEnded = True

        frames += 1
        if frames % 15 == 0:
            score += 1
        if frames > 10000000:
            frames = 0
        if frames % 30 == 0:
            new_enemy = Enemy()
            enemies.add(new_enemy)
            all_sprites.add(new_enemy)
        if frames % 40 == 0:
            new_cloud = Cloud()
            clouds.add(new_cloud)
            all_sprites.add(new_cloud)
        # update display
        pygame.display.flip()
        clock.tick(clock_tick)

    pygame.quit()
    # pygame.mixer.music.stop()
    # pygame.mixer.quit()
    quit()


old_response = None


def controlled_run(wrapper, counter):
    global score, gameEnded, player, enemies, clouds, frames

    global action_counter

    global clock_tick

    gameEnded = False
    pygame.init()
    pygame.font.init()
    caption = "Machine Learning Attempt #"+str(counter)
    gameDisplay = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption(caption)
    clock = pygame.time.Clock()
    crashed = False
    player = Player()

    enemies = pygame.sprite.Group()
    clouds = pygame.sprite.Group()
    all_sprites = pygame.sprite.Group()
    all_sprites.add(player)
    gameDisplay.fill(SKYBLUE)
    score = 0
    frames = 0

    old_score = 0
    old_action = None
    old_closest_enemy = None
    print("I'm right before the game loop")
    while not gameEnded and not crashed:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                crashed == True
            elif event.type == pygame.KEYDOWN:
                if event.key == 119 and clock_tick < MAXFPS*2:
                    clock_tick += 5
                elif event.key == 115 and clock_tick > 5:
                    clock_tick -= 5

        # stuff that needs to be run every frame
        nothingpressed = {K_DOWN: False, K_LEFT: False,
                          K_UP: False, K_RIGHT: False, K_w: False, K_s: False, K_i: False}
        update(gameDisplay, player, nothingpressed, True)
        # draw sprites
        for entity in all_sprites:
            gameDisplay.blit(entity.surf, entity.rect)

        # collision detection
        if pygame.sprite.spritecollideany(player, enemies) and not invincible:
            player.kill()
            # move_up_sound.stop()
            # move_down_sound.stop()
            # collision_sound.play()
            gameEnded = True

        frames += 1
        if frames % 15 == 0:
            score += 1
        if frames > 10000000:
            frames = 0
        if frames % 30 == 0:
            new_enemy = Enemy()
            enemies.add(new_enemy)
            all_sprites.add(new_enemy)
        if frames % 40 == 0:
            new_cloud = Cloud()
            clouds.add(new_cloud)
            all_sprites.add(new_cloud)

        # now do actions

        new_score = copy.deepcopy(score)
        score_increased = 0

        if new_score > old_score:
            score_increased = 1

        values = dict()

        if old_action is None:
            values['action'] = DO_NOTHING
        else:
            values['action'] = old_action

        if old_closest_enemy is None:
            values['old_closest_enemy'] = -1
        else:
            values['old_closest_enemy'] = old_closest_enemy

        if enemies.__len__() > 0:
            closest_enemy = SCREEN_WIDTH
            for enemy in enemies:
                if enemy.rect.x > player.rect.x and enemy.rect.x < closest_enemy:
                    closest_enemy = enemy.rect.x
            values['closest_enemy'] = closest_enemy
        else:
            values['closest_enemy'] = -1

        values['score_increased'] = score_increased

        # ask the wrapper to do the math and take an action(or not)
        # for now will only be going up or down or nothing, but will change to a list that can hold multiple commands
        response = wrapper.control(values)
        player.compUpdate(response)

        old_score = new_score
        old_closest_enemy = values['closest_enemy']
        pygame.display.flip()

    wrapper.gameover(score)


if __name__ == '__main__':
    run()
