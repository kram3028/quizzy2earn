package com.quizzy2earn.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import theoremreach.com.theoremreach.TheoremReach
import theoremreach.com.theoremreach.TheoremReachRewardListener
import theoremreach.com.theoremreach.TheoremReachSurveyListener
import theoremreach.com.theoremreach.TheoremReachSurveyAvailableListener
import android.util.Log

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.quizzy2earn/theoremreach"

        // TODO: Replace with your real values
        private const val API_KEY = "8a7ac1d52cfc694d58ce2efcff0d"
        private const val PLACEMENT_ID = "481f0622-8216-46c6-8622-87624190b0fa"
    }

    private var theoremReach: TheoremReach? = null
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        channel.setMethodCallHandler { call, result ->

            when (call.method) {

                "openTheoremReach" -> {

                    val userId =
                        call.argument<String>("userId")

                    if (userId.isNullOrBlank()) {
                        result.error(
                            "INVALID_USER",
                            "User ID is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {

                        theoremReach =
                            TheoremReach.initWithApiKeyAndUserIdAndActivityContext(
                                API_KEY,
                                userId,
                                this
                            )

                        // ------------------------------
                        // Reward Listener
                        // ------------------------------
                        theoremReach!!.setTheoremReachRewardListener(
                            object : TheoremReachRewardListener {
                                override fun onReward(reward: Int) {

                                    Log.d("TheoremReach", "Reward Earned: $reward")

                                    channel.invokeMethod(
                                        "onReward",
                                        reward
                                    )
                                }
                            }
                        )

                        // ------------------------------
                        // Survey Listener
                        // ------------------------------
                        theoremReach!!.setTheoremReachSurveyListener(
                            object : TheoremReachSurveyListener {

                                override fun onRewardCenterOpened() {

                                    Log.d("TheoremReach", "Reward Center Opened")

                                    channel.invokeMethod(
                                        "onRewardCenterOpened",
                                        null
                                    )
                                }

                                override fun onRewardCenterClosed() {

                                    Log.d("TheoremReach", "Reward Center Closed")

                                    channel.invokeMethod(
                                        "onRewardCenterClosed",
                                        null
                                    )
                                }
                            }
                        )

                        // ------------------------------
                        // Survey Available Listener
                        // ------------------------------
                        theoremReach!!.setTheoremReachSurveyAvailableListener(
                            object : TheoremReachSurveyAvailableListener {

                                override fun theoremreachSurveyAvailable(
                                    available: Boolean
                                ) {

                                    Log.d(
                                        "TheoremReach",
                                        "Survey Available = $available"
                                    )

                                    channel.invokeMethod(
                                        "onSurveyAvailable",
                                        available
                                    )
                                }
                            }
                        )

                        // Open Reward Center
                        theoremReach!!.showRewardCenter(
                            PLACEMENT_ID
                        )

                        result.success(true)

                    } catch (e: Exception) {

                        result.error(
                            "THEOREMREACH_ERROR",
                            e.message,
                            null
                        )

                    }

                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()

        theoremReach?.onResume(this)
    }

    override fun onPause() {

        theoremReach?.onPause()

        super.onPause()
    }
}