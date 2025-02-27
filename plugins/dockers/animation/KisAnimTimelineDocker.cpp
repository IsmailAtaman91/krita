/*
 *  SPDX-FileCopyrightText: 2015 Jouni Pentikäinen <joupent@gmail.com>
 *  SPDX-FileCopyrightText: 2020 Emmet O 'Neill <emmetoneill.pdx@gmail.com>
 *  SPDX-FileCopyrightText: 2020 Eoin O 'Neill <eoinoneill1991@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "KisAnimTimelineDocker.h"

#include <QPointer>
#include "QHBoxLayout"
#include "QVBoxLayout"
#include "QFormLayout"
#include "QLabel"
#include "QToolButton"
#include "QMenu"
#include "QWidgetAction"

#include "krita_utils.h"
#include "kis_canvas2.h"
#include "kis_image.h"
#include <KoIcon.h>
#include "KisViewManager.h"
#include "kis_paint_layer.h"
#include "KisDocument.h"
#include "kis_dummies_facade.h"
#include "kis_shape_controller.h"
#include "kis_action.h"
#include "kis_action_manager.h"
#include "KisCanvasAnimationState.h"
#include "animation/KisFrameDisplayProxy.h"
#include "KisAnimUtils.h"
#include "kis_image_config.h"
#include "kis_keyframe_channel.h"
#include "kis_image.h"
#include "KisPart.h"
#include "KisPlaybackEngine.h"

#include "KisAnimTimelineFramesModel.h"
#include "KisAnimTimelineFramesView.h"
#include "kis_time_span.h"
#include "kis_animation_frame_cache.h"
#include "kis_image_animation_interface.h"
#include "kis_signal_auto_connection.h"
#include "kis_node_manager.h"
#include "kis_transport_controls.h"
#include "kis_int_parse_spin_box.h"
#include "kis_slider_spin_box.h"
#include "kis_signals_blocker.h"
#include "KisMainWindow.h"

KisAnimTimelineDockerTitlebar::KisAnimTimelineDockerTitlebar(QWidget* parent) :
    KisUtilityTitleBar(new QLabel(i18n("Animation Timeline"), parent), parent)
{
    setFocusPolicy(Qt::ClickFocus);

    // Transport Controls...
    transport = new KisTransportControls(this);
    transport->showSkipButtons(true);
    widgetAreaLayout->addWidget(transport);

    widgetAreaLayout->addSpacing(SPACING_UNIT);

    // Frame Register...
    frameRegister = new KisIntParseSpinBox(this);
    frameRegister->setToolTip(i18n("Frame register"));
    frameRegister->setPrefix("#  ");
    frameRegister->setRange(0, MAX_FRAMES);
    widgetAreaLayout->addWidget(frameRegister);

    widgetAreaLayout->addSpacing(SPACING_UNIT);

    {   // Drop Frames..
        btnDropFrames = new QToolButton(this);
        btnDropFrames->setAutoRaise(true);
        widgetAreaLayout->addWidget(btnDropFrames);

        // Playback Speed..
        sbSpeed = new KisSliderSpinBox(this);
        sbSpeed->setRange(25, 200);
        sbSpeed->setSingleStep(5);
        sbSpeed->setValue(100);
        sbSpeed->setPrefix(i18nc("preview playback speed percentage prefix", "Speed: "));
        sbSpeed->setSuffix(" %");
        sbSpeed->setToolTip(i18n("Preview playback speed"));
        sbSpeed->setEnabled(KisPart::instance()->playbackEngine()->supportsVariablePlaybackSpeed());

        widgetAreaLayout->addWidget(sbSpeed);
    }

    widgetAreaLayout->addSpacing(SPACING_UNIT);

    {   // Frame ops...
        QWidget *widget = new QWidget(this);
        QHBoxLayout *layout = new QHBoxLayout(widget);
        layout->setSpacing(0);
        layout->setContentsMargins(0,0,0,0);

        btnAddKeyframe = new QToolButton(this);
        btnAddKeyframe->setAutoRaise(true);
        layout->addWidget(btnAddKeyframe);

        btnDuplicateKeyframe = new QToolButton(this);
        btnDuplicateKeyframe->setAutoRaise(true);
        layout->addWidget(btnDuplicateKeyframe);

        btnRemoveKeyframe = new QToolButton(this);
        btnRemoveKeyframe->setAutoRaise(true);
        layout->addWidget(btnRemoveKeyframe);

        widgetAreaLayout->addWidget(widget);
    }

    widgetAreaLayout->addStretch();

    {   // Menus..
        QWidget *widget = new QWidget(this);

        QHBoxLayout *layout = new QHBoxLayout(widget);
        layout->setSpacing(0);
        layout->setContentsMargins(SPACING_UNIT,0,0,0);

        // Onion skins menu.
        btnOnionSkinsMenu = new QToolButton(this);
        btnOnionSkinsMenu->setIcon(KisIconUtils::loadIcon("onion_skin_options"));
        btnOnionSkinsMenu->setToolTip(i18n("Onion skins menu"));
        btnOnionSkinsMenu->setIconSize(QSize(22, 22));
        btnOnionSkinsMenu->setAutoRaise(true);
        layout->addWidget(btnOnionSkinsMenu);

        {   // Audio menu..
            btnAudioMenu = new QToolButton(this);
            btnAudioMenu->setIcon(KisIconUtils::loadIcon("audio-none"));
            btnAudioMenu->setToolTip(i18n("Animation audio menu"));
            btnAudioMenu->setIconSize(QSize(22, 22));
            btnAudioMenu->setAutoRaise(true);
            btnAudioMenu->setEnabled(KisPart::instance()->playbackEngine()->supportsAudio());

            QMenu *audioMenu = new QMenu(this);

            strImportAudio = QString(i18nc("@item:inmenu Load audio file into Krita from disk.", "Import Audio..."));
            importAudioAction = new QAction(strImportAudio, audioMenu);
            removeAudioAction = new QAction(i18nc("@item:inmenu", "Remove audio"), audioMenu);

            muteAudioAction = new QAction(i18nc("@item:inmenu Mute audio playback.", "Mute"), audioMenu);
            muteAudioAction->setCheckable(true);

            volumeSlider = new KisSliderSpinBox(audioMenu);
            volumeSlider->setRange(0, 100);
            volumeSlider->setSuffix(i18n("%"));
            volumeSlider->setPrefix(i18nc("@item:inmenu Volume slider", "Volume: "));
            volumeSlider->setSingleStep(1);
            volumeSlider->setPageStep(10);
            volumeSlider->setSizePolicy(QSizePolicy::Ignored, QSizePolicy::Fixed);

            QWidgetAction *volumeAction = new QWidgetAction(audioMenu);
            volumeAction->setDefaultWidget(volumeSlider);

            audioMenu->addSeparator();

            audioMenu->addAction(importAudioAction);
            audioMenu->addAction(removeAudioAction);

            audioMenu->addSeparator();

            audioMenu->addAction(volumeAction);
            audioMenu->addAction(muteAudioAction);

            btnAudioMenu->setPopupMode(QToolButton::InstantPopup);
            btnAudioMenu->setMenu(audioMenu);
            btnAudioMenu->setEnabled(false); // To be enabled on canvas load...

            layout->addWidget(btnAudioMenu);
        }

        {   // Settings menu..
            btnSettingsMenu = new QToolButton(this);
            btnSettingsMenu->setIcon(KisIconUtils::loadIcon("view-choose-22"));
            btnSettingsMenu->setToolTip(i18n("Animation settings menu"));
            btnSettingsMenu->setIconSize(QSize(22, 22));
            btnSettingsMenu->setAutoRaise(true);

            QWidget *settingsMenuWidget = new QWidget(this);
            QHBoxLayout *settingsMenuLayout = new QHBoxLayout(settingsMenuWidget);

            QWidget *fields = new QWidget(settingsMenuWidget);
            QFormLayout *fieldsLayout = new QFormLayout(fields);

            sbStartFrame = new KisIntParseSpinBox(settingsMenuWidget);
            sbStartFrame->setMaximum(10000);
            fieldsLayout->addRow(i18n("Clip Start: "), sbStartFrame);

            sbEndFrame = new KisIntParseSpinBox(settingsMenuWidget);
            sbEndFrame->setMaximum(10000);
            fieldsLayout->addRow(i18n("Clip End: "), sbEndFrame);

            sbFrameRate = new KisIntParseSpinBox(settingsMenuWidget);
            sbFrameRate->setMinimum(0);
            sbFrameRate->setMaximum(120);
            fieldsLayout->addRow(i18n("Frame Rate: "), sbFrameRate);

            QWidget *buttons = new QWidget(settingsMenuWidget);
            QVBoxLayout *buttonsLayout = new QVBoxLayout(buttons);
            buttonsLayout->setAlignment(Qt::AlignTop);

            {   // AutoKey..
                // AutoKey Actions & Action Group..
                autoKeyBlank = new QAction(i18n("AutoKey Blank"), this);
                autoKeyBlank->setCheckable(true);
                autoKeyDuplicate = new QAction(i18n("AutoKey Duplicate"), this);
                autoKeyDuplicate->setCheckable(true);
                QActionGroup *autoKeyModes = new QActionGroup(this);
                autoKeyModes->addAction(autoKeyBlank);
                autoKeyModes->addAction(autoKeyDuplicate);
                autoKeyModes->setExclusive(true);

                connect(autoKeyModes, &QActionGroup::triggered, [this](QAction* modeAction){
                    if (!modeAction) return;
                    KisImageConfig  imageCfg(false);
                    if (modeAction == autoKeyBlank) {
                        imageCfg.setAutoKeyModeDuplicate(false);
                    } else if (modeAction == autoKeyDuplicate) {
                        imageCfg.setAutoKeyModeDuplicate(true);
                    }
                });

                // AutoKey Mode Menu..
                QMenu *autoKeyModeMenu = new QMenu(settingsMenuWidget);
                autoKeyModeMenu->addActions(autoKeyModes->actions());

                // AutoKey Button..
                btnAutoKey = new QToolButton(settingsMenuWidget);
                btnAutoKey->setMenu(autoKeyModeMenu);
                btnAutoKey->setPopupMode(QToolButton::MenuButtonPopup);
                buttonsLayout->addWidget(btnAutoKey);
            }

            settingsMenuLayout->addWidget(fields);
            settingsMenuLayout->addWidget(buttons);

            layout->addWidget(btnSettingsMenu);

            QMenu *settingsPopMenu = new QMenu(this);
            QWidgetAction *settingsMenuAction = new QWidgetAction(this);
            settingsMenuAction->setDefaultWidget(settingsMenuWidget);
            settingsPopMenu->addAction(settingsMenuAction);

            btnSettingsMenu->setPopupMode(QToolButton::InstantPopup);
            btnSettingsMenu->setMenu(settingsPopMenu);
        }

        widgetAreaLayout->addWidget(widget);
    }
}



struct KisAnimTimelineDocker::Private
{
    Private(QWidget *parent)
        : framesModel(new KisAnimTimelineFramesModel(parent))
        , framesView(new KisAnimTimelineFramesView(parent))
        , titlebar(new KisAnimTimelineDockerTitlebar(parent))
        , mainWindow(nullptr)
    {
        framesView->setModel(framesModel);
        framesView->setMinimumHeight(50);

        connect(titlebar->importAudioAction, &QAction::triggered, framesView, &KisAnimTimelineFramesView::slotSelectAudioChannelFile);
        connect(titlebar->removeAudioAction, &QAction::triggered, framesView, [&](){framesView->slotAudioChannelRemove();});
        connect(titlebar->muteAudioAction, &QAction::triggered, framesView, &KisAnimTimelineFramesView::slotAudioChannelMute);
        connect(titlebar->volumeSlider, SIGNAL(valueChanged(int)), framesView, SLOT(slotAudioVolumeChanged(int)));
    }

    KisAnimTimelineFramesModel *framesModel;
    KisAnimTimelineFramesView *framesView;
    KisAnimTimelineDockerTitlebar *titlebar;

    QPointer<KisCanvas2> canvas;

    KisSignalAutoConnectionsStore canvasConnections;
    KisMainWindow *mainWindow;
};



KisAnimTimelineDocker::KisAnimTimelineDocker()
    : QDockWidget(i18n("Animation Timeline"))
    , m_d(new Private(this))
{
    setWidget(m_d->framesView);

    // Titlebar Widget..
    setTitleBarWidget(m_d->titlebar);

    connect(m_d->titlebar->btnOnionSkinsMenu, &QToolButton::released, [this](){
        if (m_d->mainWindow) {
            QDockWidget *docker = m_d->mainWindow->dockWidget("OnionSkinsDocker");
            if (docker) {
                docker->setVisible(!docker->isVisible());
            }
        }
    });

    connect(m_d->titlebar->transport, SIGNAL(skipBack()), KisPart::instance()->playbackEngine(), SLOT(previousKeyframe()));
    connect(m_d->titlebar->transport, SIGNAL(back()), KisPart::instance()->playbackEngine(), SLOT(previousFrame()));
    connect(m_d->titlebar->transport, SIGNAL(stop()), KisPart::instance()->playbackEngine(), SLOT(stop()));
    connect(m_d->titlebar->transport, SIGNAL(playPause()), KisPart::instance()->playbackEngine(), SLOT(playPause()));
    connect(m_d->titlebar->transport, SIGNAL(forward()), KisPart::instance()->playbackEngine(), SLOT(nextFrame()));
    connect(m_d->titlebar->transport, SIGNAL(skipForward()), KisPart::instance()->playbackEngine(), SLOT(nextKeyframe()));

    connect(m_d->titlebar->frameRegister, SIGNAL(valueChanged(int)), KisPart::instance()->playbackEngine(), SLOT(seek(int)));
    connect(m_d->titlebar->sbSpeed, SIGNAL(valueChanged(int)), KisPart::instance()->playbackEngine(), SLOT(setPlaybackSpeedPercent(int)));

    setEnabled(false);
}

KisAnimTimelineDocker::~KisAnimTimelineDocker()
{
}

struct NodeManagerInterface : KisAnimTimelineFramesModel::NodeManipulationInterface
{
    NodeManagerInterface(KisNodeManager *manager) : m_manager(manager) {}

    KisLayerSP addPaintLayer() const override {
        return m_manager->createPaintLayer();
    }

    void removeNode(KisNodeSP node) const override {
        m_manager->removeSingleNode(node);
    }

    bool setNodeProperties(KisNodeSP node, KisImageSP image, KisBaseNode::PropertyList properties) const override
    {
        return m_manager->trySetNodeProperties(node, image, properties);
    }

private:
    KisNodeManager *m_manager;
};

void KisAnimTimelineDocker::setCanvas(KoCanvasBase * canvas)
{
    if (m_d->canvas == canvas) return;

    if (m_d->framesModel->hasConnectionToCanvas()) {
        m_d->canvasConnections.clear();
        m_d->framesModel->setDummiesFacade(0, 0, 0);
        m_d->framesModel->setFrameCache(0);
        m_d->framesModel->setAnimationPlayer(0);
        m_d->framesModel->setDocument(0);
        m_d->framesModel->setNodeManipulationInterface(0);
    }

    // Deinitialize from previous canvas...
    if (m_d->canvas) { 
        m_d->canvas->disconnectCanvasObserver(this);
        m_d->canvas->animationState()->disconnect(this);
        m_d->titlebar->transport->setPlaying(false);

        m_d->titlebar->btnAudioMenu->setEnabled(false);

        if(m_d->canvas->image()) {
            m_d->canvas->image()->animationInterface()->disconnect(this);
            m_d->titlebar->sbStartFrame->disconnect(m_d->canvas->image()->animationInterface());
            m_d->titlebar->sbEndFrame->disconnect(m_d->canvas->image()->animationInterface());
            m_d->titlebar->sbFrameRate->disconnect(m_d->canvas->image()->animationInterface());
        }
    }

    m_d->canvas = dynamic_cast<KisCanvas2*>(canvas);
    setEnabled(m_d->canvas != 0);
    m_d->framesView->slotCanvasUpdate(m_d->canvas);

    // Reinitialize new canvas..
    if (m_d->canvas) {
        KisDocument *doc = static_cast<KisDocument*>(m_d->canvas->imageView()->document());
        KisShapeController *kritaShapeController = dynamic_cast<KisShapeController*>(doc->shapeController());
        m_d->framesModel->setDummiesFacade(kritaShapeController,
                                     m_d->canvas->image(),
                                     m_d->canvas->viewManager()->nodeManager()->nodeDisplayModeAdapter());

        m_d->framesModel->setDocument(doc);

        updateFrameCache();

        {   // Titlebar widgets...
            KisSignalsBlocker blocker(m_d->titlebar->sbStartFrame,
                                      m_d->titlebar->sbEndFrame,
                                      m_d->titlebar->sbFrameRate,
                                      m_d->titlebar->sbSpeed,
                                      m_d->titlebar->frameRegister);

            KisImageAnimationInterface *animinterface = m_d->canvas->image()->animationInterface();
            m_d->titlebar->sbStartFrame->setValue(animinterface->documentPlaybackRange().start());
            m_d->titlebar->sbEndFrame->setValue(animinterface->documentPlaybackRange().end());
            m_d->titlebar->sbFrameRate->setValue(animinterface->framerate());
            m_d->titlebar->sbSpeed->setValue(100);
            m_d->titlebar->frameRegister->setValue(animinterface->currentTime());
            
            m_d->titlebar->btnAudioMenu->setEnabled(true); // Menu is disabled until a canvas is loaded.
        }

        m_d->framesModel->setAnimationPlayer(m_d->canvas->animationState());

        m_d->framesModel->setNodeManipulationInterface(
            new NodeManagerInterface(m_d->canvas->viewManager()->nodeManager()));

        m_d->canvasConnections.addConnection(
            m_d->canvas->viewManager()->nodeManager(), SIGNAL(sigNodeActivated(KisNodeSP)),
            m_d->framesModel, SLOT(slotCurrentNodeChanged(KisNodeSP)));

        m_d->canvasConnections.addConnection(
            m_d->framesModel, SIGNAL(requestCurrentNodeChanged(KisNodeSP)),
            m_d->canvas->viewManager()->nodeManager(), SLOT(slotNonUiActivatedNode(KisNodeSP)));

        m_d->framesModel->slotCurrentNodeChanged(m_d->canvas->viewManager()->activeNode());

        m_d->canvasConnections.addConnection(
                    m_d->canvas->viewManager()->mainWindow(), SIGNAL(themeChanged()),
                    this, SLOT(handleThemeChange()));

        m_d->canvasConnections.addConnection(
                    m_d->canvas, SIGNAL(sigCanvasEngineChanged()),
                    this, SLOT(updateFrameCache()));

        m_d->titlebar->transport->setPlaying(m_d->canvas->animationState()->playbackState() == PlaybackState::PLAYING);

        m_d->titlebar->volumeSlider->setValue(m_d->framesModel->audioVolume() * 100.0);

        connect(m_d->titlebar->sbFrameRate, SIGNAL(valueChanged(int)), m_d->canvas->image()->animationInterface(), SLOT(setFramerate(int)));
        connect(m_d->titlebar->sbStartFrame, SIGNAL(valueChanged(int)), m_d->canvas->image()->animationInterface(), SLOT(setDocumentRangeStartFrame(int)));
        connect(m_d->titlebar->sbEndFrame, SIGNAL(valueChanged(int)), m_d->canvas->image()->animationInterface(), SLOT(setDocumentRangeEndFrame(int)));

        connect(m_d->canvas->animationState(), SIGNAL(sigFrameChanged()), this, SLOT(updateFrameRegister()));
        connect(m_d->canvas->animationState(), &KisCanvasAnimationState::sigPlaybackStateChanged, [this](PlaybackState state){
            m_d->titlebar->frameRegister->setDisabled(state == PlaybackState::PLAYING);
            if (state == PlaybackState::STOPPED) {
                updateFrameRegister();
            }
        });
        connect(m_d->canvas->animationState(), &KisCanvasAnimationState::sigPlaybackStateChanged, [this](PlaybackState state){
            m_d->titlebar->transport->setPlaying(state == PlaybackState::PLAYING);
        });

        connect(m_d->canvas->image()->animationInterface(), SIGNAL(sigUiTimeChanged(int)), this, SLOT(updateFrameRegister()));

        connect(m_d->canvas->image()->animationInterface(), &KisImageAnimationInterface::sigPlaybackRangeChanged, this, [this]() {
            if (!m_d->canvas || !m_d->canvas->image()) return;

            KisImageAnimationInterface *animInterface = m_d->canvas->image()->animationInterface();

            m_d->titlebar->sbStartFrame->setValue(animInterface->documentPlaybackRange().start());
            m_d->titlebar->sbEndFrame->setValue(animInterface->documentPlaybackRange().end());
        });

        connect(m_d->canvas->image()->animationInterface(), SIGNAL(sigFramerateChanged()), SLOT(handleFrameRateChange()));
    }
}

void KisAnimTimelineDocker::handleThemeChange()
{
    if (m_d->framesView) {
        m_d->framesView->slotUpdateIcons();
    }
}

void KisAnimTimelineDocker::updateFrameCache()
{
    m_d->framesModel->setFrameCache(m_d->canvas->frameCache());
}

void KisAnimTimelineDocker::updateFrameRegister()
{
    if (!m_d->canvas && !m_d->canvas->image()) {
        return;
    }

    const int frame = m_d->canvas->animationState()->displayProxy()->activeFrame();

    QSignalBlocker blocker(m_d->titlebar->frameRegister);
    m_d->titlebar->frameRegister->setValue(frame);
}

void KisAnimTimelineDocker::updatePlaybackStatistics()
{
    qreal effectiveFps = 0.0;
    qreal realFps = 0.0;
    qreal framesDropped = 0.0;
    bool isPlaying = false;

    KisCanvasAnimationState *player = m_d->canvas &&  m_d->canvas->animationState() ?  m_d->canvas->animationState() : 0;
    if (player) {
//        effectiveFps = player->effectiveFps();
//        realFps = player->realFps();
//        framesDropped = player->framesDroppedPortion();
//        isPlaying = player->isPlaying();
    }

    KisConfig cfg(true);
    const bool shouldDropFrames = cfg.animationDropFrames();

    QAction *action = m_d->titlebar->btnDropFrames->defaultAction();
    const bool droppingFrames = shouldDropFrames && framesDropped > 0.05;
    action->setIcon(KisIconUtils::loadIcon(droppingFrames ? "droppedframes" : "dropframe"));

    QString actionText;
    if (!isPlaying) {
        actionText = QString("%1 (%2) \n%3")
            .arg(KisAnimUtils::dropFramesActionName)
            .arg(KritaUtils::toLocalizedOnOff(shouldDropFrames))
            .arg(i18n("Enable to preserve playback timing."));
    } else {
        actionText = QString("%1 (%2)\n"
                       "%3\n"
                       "%4\n"
                       "%5")
            .arg(KisAnimUtils::dropFramesActionName)
            .arg(KritaUtils::toLocalizedOnOff(shouldDropFrames))
            .arg(i18n("Effective FPS:\t%1", effectiveFps))
            .arg(i18n("Real FPS:\t%1", realFps))
            .arg(i18n("Frames dropped:\t%1\%", framesDropped * 100));
    }
    action->setText(actionText);
}

void KisAnimTimelineDocker::unsetCanvas()
{
    setCanvas(0);
}

void KisAnimTimelineDocker::setViewManager(KisViewManager *view)
{
    m_d->mainWindow = view->mainWindow();
    KisActionManager *actionManager = view->actionManager();
    m_d->framesView->setActionManager(actionManager);

    KisAction *action = 0;

    KisAnimTimelineDockerTitlebar* titleBar = static_cast<KisAnimTimelineDockerTitlebar*>(titleBarWidget());

    action = actionManager->actionByName("add_blank_frame");
    titleBar->btnAddKeyframe->setDefaultAction(action);
    titleBar->btnAddKeyframe->setIconSize(QSize(22, 22));

    action = actionManager->actionByName("add_duplicate_frame");
    titleBar->btnDuplicateKeyframe->setDefaultAction(action);
    titleBar->btnDuplicateKeyframe->setIconSize(QSize(22, 22));

    action = actionManager->actionByName("remove_frames");
    titleBar->btnRemoveKeyframe->setDefaultAction(action);
    titleBar->btnRemoveKeyframe->setIconSize(QSize(22, 22));

    action = actionManager->createAction("toggle_playback");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, [this](bool){
        KisPart::instance()->playbackEngine()->playPause();
    });

    action = actionManager->createAction("stop_playback");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, [this](bool){
        KisPart::instance()->playbackEngine()->stop();
    });

    action = actionManager->createAction("previous_frame");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, [this](bool){
        KisPart::instance()->playbackEngine()->previousFrame();
    });

    action = actionManager->createAction("next_frame");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, [this](bool){
        KisPart::instance()->playbackEngine()->nextFrame();
    });

    action = actionManager->createAction("previous_keyframe");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, this, [](bool){
        KisPart::instance()->playbackEngine()->previousKeyframe();
    });

    action = actionManager->createAction("next_keyframe");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, this, [](bool){
        KisPart::instance()->playbackEngine()->nextKeyframe();
    });

    action = actionManager->createAction("previous_matching_keyframe");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, this, [](bool){
        KisPart::instance()->playbackEngine()->previousMatchingKeyframe();
    });

    action = actionManager->createAction("next_matching_keyframe");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, this, [](bool){
        KisPart::instance()->playbackEngine()->nextMatchingKeyframe();
    });

    action = actionManager->createAction("previous_unfiltered_keyframe");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, this, [](bool){
        KisPart::instance()->playbackEngine()->previousUnfilteredKeyframe();
    });

    action = actionManager->createAction("next_unfiltered_keyframe");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, this, [](bool){
        KisPart::instance()->playbackEngine()->nextUnfilteredKeyframe();
    });

    action = actionManager->createAction("first_frame");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, [this](bool){
       if (m_d->canvas) {
           KisPart::instance()->playbackEngine()->firstFrame();
       }
    });

    action = actionManager->createAction("last_frame");
    action->setActivationFlags(KisAction::ACTIVE_IMAGE);
    connect(action, &KisAction::triggered, [this](bool){
       if (m_d->canvas) {
           KisPart::instance()->playbackEngine()->lastFrame();
       }
    });

    action = actionManager->createAction("auto_key");
    m_d->titlebar->btnAutoKey->setDefaultAction(action);
    m_d->titlebar->btnAutoKey->setIconSize(QSize(22, 22));
    connect(action, SIGNAL(triggered(bool)), SLOT(setAutoKey(bool)));

    {
        KisImageConfig config(true);
        action->setChecked(config.autoKeyEnabled());
        action->setIcon(config.autoKeyEnabled() ? KisIconUtils::loadIcon("auto-key-on") : KisIconUtils::loadIcon("auto-key-off"));

        const bool autoKeyModeDuplicate = config.autoKeyModeDuplicate();
        m_d->titlebar->autoKeyBlank->setChecked(!autoKeyModeDuplicate);
        m_d->titlebar->autoKeyDuplicate->setChecked(autoKeyModeDuplicate);
    }

    {
        action = actionManager->createAction("drop_frames");
        m_d->titlebar->btnDropFrames->setDefaultAction(action);
        m_d->titlebar->btnDropFrames->setIconSize(QSize(22, 22));
        connect(action, &KisAction::triggered, [this](bool dropFrames){
            KisConfig cfg(false);
            if (dropFrames != cfg.animationDropFrames()) {
                cfg.setAnimationDropFrames(dropFrames);
                updatePlaybackStatistics();
            }
        });

        KisConfig config(true);
        action->setChecked(config.animationDropFrames());
    }
}

void KisAnimTimelineDocker::setAutoKey(bool value)
{
    KisImageConfig cfg(false);
    if (value != cfg.autoKeyEnabled()) {
        cfg.setAutoKeyEnabled(value);
        const QIcon icon = cfg.autoKeyEnabled() ? KisIconUtils::loadIcon("auto-key-on") : KisIconUtils::loadIcon("auto-key-off");
        QAction* action = m_d->titlebar->btnAutoKey->defaultAction();
        action->setIcon(icon);
    }
}

void KisAnimTimelineDocker::handleFrameRateChange()
{
    if (!m_d->canvas || !m_d->canvas->image()) return;

    KisImageAnimationInterface *animInterface = m_d->canvas->image()->animationInterface();

    m_d->titlebar->sbFrameRate->setValue(animInterface->framerate());
}

void KisAnimTimelineDocker::handlePlaybackSpeedChange(double normalizedPlaybackSpeed)
{
    m_d->titlebar->sbSpeed->setValue(normalizedPlaybackSpeed * 100);
}


