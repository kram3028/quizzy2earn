const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const axios = require("axios");
const functions = require("firebase-functions");

admin.initializeApp();

exports.generateWithdrawTransactionId = onDocumentCreated(
  {
    document: "withdraw_requests/{withdrawId}",
    region: "us-central1",
  },
  async (event) => {

    const snap = event.data;
    const data = snap.data();

    const withdrawId = event.params.withdrawId;
    const uid = data.userId;

    const now = Date.now();

    // 🔒 Secure internal ID
    const transactionId =
      `TX-${uid.substring(0,6)}-${withdrawId.substring(0,6)}-${now}`;

    // 📅 Support friendly ID
    const date = new Date();
    const datePart =
      date.getFullYear().toString().slice(2) +
      String(date.getMonth()+1).padStart(2,'0') +
      String(date.getDate()).padStart(2,'0');

    const todayStart = new Date(date.setHours(0,0,0,0));

    const todaySnapshot = await admin.firestore()
      .collection("withdraw_requests")
      .where("createdAt", ">=", todayStart)
      .get();

    const count = todaySnapshot.size + 1;

    const supportId =
      `TX${datePart}-${String(count).padStart(5,'0')}`;

    await snap.ref.update({
      transactionId,
      supportId
    });

  }
);

/**
 * 🔥 AUTO SETTLE COINS AFTER ADMIN ACTION
 * Runs when admin updates withdraw_requests status
 */
exports.onWithdrawStatusChange = onDocumentUpdated(
  {
    document: "withdraw_requests/{withdrawId}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // No status change → do nothing
    if (before.status === after.status) return;

    // Already settled → do nothing
    if (after.coinsSettled === true) return;

    const userId = after.userId;
    const coinsUsed = Number(after.coinsUsed || 0);

    const userRef = admin.firestore().collection("users").doc(userId);
    const withdrawRef = event.data.after.ref;

    await admin.firestore().runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) return;

      const coinsAvailable = Number(userSnap.data().coinsAvailable || 0);
      const coinsLocked = Number(userSnap.data().coinsLocked || 0);

      if (after.status === "paid") {
        // ✅ PAID → remove locked coins
        tx.update(userRef, {
          coinsLocked: Math.max(coinsLocked - coinsUsed, 0),
        });
      }

      if (after.status === "rejected") {
        // ❌ REJECTED → return coins to available
        tx.update(userRef, {
          coinsAvailable: coinsAvailable + coinsUsed,
          coinsLocked: Math.max(coinsLocked - coinsUsed, 0),
        });
      }

      // 🔒 Mark as settled (VERY IMPORTANT)
      tx.update(withdrawRef, {
        coinsSettled: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    const amount = after.requestedAmount || 0;

    console.log(
      `Coins settled for ${userId}, status=${after.status}, amount=${amount}`
    );
    const messaging = admin.messaging();

    async function sendWithdrawNotification(userId, status, amount) {
      const userSnap = await admin.firestore().collection("users").doc(userId).get();
      if (!userSnap.exists) return;

      const token = userSnap.data().fcmToken;
      if (!token) return;

      const title =
        status === "paid"
          ? "Withdrawal Successful 🎉"
          : "Withdrawal Rejected ❌";

      const body =
        status === "paid"
          ? `₹${amount} has been sent to your account`
          : `₹${amount} withdrawal was rejected`;

      await messaging.send({
        token,
        notification: {
          title,
          body,
        },
        data: {
          type: "withdraw_status",
          status,
          amount: amount.toString(),
        },
      });
    }
  }
);

// 🔥 DAILY LOGIN BONUS (SECURE)
exports.claimDailyLogin = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new Error("Unauthenticated");
    }

    const userRef = admin.firestore().collection("users").doc(uid);

    const rewards = [10, 20, 30, 50, 80, 120, 150];

    return admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(userRef);

      if (!snap.exists) {
        throw new Error("User not found");
      }

      const user = snap.data();

      const daily = user.dailyLogin || {};

      let streak = daily.streak || 0;
      const lastClaim = daily.lastClaim;

      const now = admin.firestore.Timestamp.now();

      // 🔐 Prevent multiple claims
      if (lastClaim) {
        const diffHours =
          (now.toDate() - lastClaim.toDate()) / (1000 * 60 * 60);

        if (diffHours < 24) {
          throw new Error("Already claimed today");
        }

        // Soft reset if missed 2 days
        if (diffHours > 48) {
          streak = 0;
        }
      }

      // Increase streak
      streak = Math.min(streak + 1, 7);

      const reward = rewards[streak - 1];

      tx.update(userRef, {
        coinsAvailable: admin.firestore.FieldValue.increment(reward),
        totalCoinsEarned: admin.firestore.FieldValue.increment(reward),

        // ⭐ WEEKLY BONUS TRACKING
        "bonus.weeklyEarned": admin.firestore.FieldValue.increment(reward),

        "dailyLogin.streak": streak,
        "dailyLogin.lastClaim": now,
      });

      return {
        success: true,
        reward,
        streak,
      };
    });
  }
);

exports.onReferralMilestone = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after.referredBy) return;
    if (after.referralRewardGiven === true) return;

    const milestoneReached =
      after.emailVerified === true &&
      (after.quizLevelsCompleted || 0) >= 10 &&
      (after.totalCoinsEarned || 0) >= 2500 &&
      (after.activeDays || 0) >= 3;

    if (!milestoneReached) return;

    const refereeId = event.params.userId;
    const referrerId = after.referredBy;

    const referrerRef = admin.firestore().collection("users").doc(referrerId);
    const refereeRef = event.data.after.ref;

    /// 🔥 FAKE REFERRAL DETECTION
    const referrerSnap = await referrerRef.get();
    const refereeSnap = await refereeRef.get();

    if (!referrerSnap.exists || !refereeSnap.exists) return;

    const referrerData = referrerSnap.data();
    const refereeData = refereeSnap.data();

    const referrerFingerprint =
      referrerData?.deviceInfo?.fingerprint;
    const refereeFingerprint =
      refereeData?.deviceInfo?.fingerprint;

    /// ❌ Same device → fake referral
    if (
      referrerFingerprint &&
      refereeFingerprint &&
      referrerFingerprint === refereeFingerprint
    ) {
      await refereeRef.set(
        {
          fraud: {
            fakeReferral: true,
            isBlocked: true,
          },
        },
        { merge: true }
      );

      console.log("Fake referral blocked");
      return;
    }

    /// ✅ Give reward if clean
    await admin.firestore().runTransaction(async (tx) => {
      const referrerSnapTx = await tx.get(referrerRef);
      if (!referrerSnapTx.exists) return;

      const currentCoins =
        Number(referrerSnapTx.data().coinsAvailable || 0);

      tx.update(referrerRef, {
        coinsAvailable: currentCoins + 500,
      });

      tx.update(refereeRef, {
        referralRewardGiven: true,
      });
    });

    console.log("Referral milestone reward given");
  }
);

exports.onQuizCompletedMission = onDocumentCreated(
  {
    document: "quiz_sessions/{quizId}",
    region: "us-central1",
  },
  async (event) => {
    const data = event.data.data();
    const userId = data.userId;

    const today = new Date().toISOString().split("T")[0];

    const missionRef = admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("missions")
      .doc("daily");

    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(missionRef);

      if (!snap.exists || snap.data().date !== today) {
        tx.set(missionRef, {
          date: today,
          quizCompleted: 1,
          rewardClaimed: false,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      } else {
        tx.update(missionRef, {
          quizCompleted: admin.firestore.FieldValue.increment(1),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
  }
);

exports.onSpinUsedMission = onDocumentCreated(
  {
    document: "daily_spin/{spinId}",
  },
  async (event) => {
    const userId = event.data.data().userId;

    const today = new Date().toISOString().split("T")[0];

    const missionRef = admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("missions")
      .doc("daily");

    await missionRef.set({
      spinUsed: admin.firestore.FieldValue.increment(1),
      date: today,
    }, { merge: true });
  }
);

exports.checkDailyMissionComplete = onDocumentUpdated(
  {
    document: "users/{userId}/missions/daily",
  },
  async (event) => {
    const data = event.data.after.data();

    const complete =
      (data.quizCompleted || 0) >= 10 &&
      (data.spinUsed || 0) >= 2;

    if (!complete || data.rewardClaimed) return;

    const userRef = event.data.after.ref.parent.parent;

    await admin.firestore().runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);

      tx.update(userRef, {
        coinsAvailable:
          (userSnap.data().coinsAvailable || 0) + 200,
      });

      tx.update(event.data.after.ref, {
        rewardClaimed: true,
      });
    });
  }
);

exports.weeklyMissionReset = onSchedule(
  {
    schedule: "30 18 * * 6", // Sunday 00:00 IST
    region: "us-central1",
  },
  async () => {

    const usersSnapshot = await admin.firestore()
      .collection("users")
      .get();

    const batch = admin.firestore().batch();

    const currentWeek = getCurrentWeekId();

    usersSnapshot.docs.forEach((doc) => {

      const userRef = doc.ref;
      const weeklyRef = userRef.collection("missions").doc("weekly");

      /// Reset weekly mission progress
      batch.set(
        weeklyRef,
        {
          weekId: currentWeek,
          coinsEarned: 0,
          daysActive: 0,
          quizCompleted: 0,
          rewardClaimed: false,
          lastReset: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      /// ⭐ RESET WEEKLY BONUS TRACKER
      batch.set(
        userRef,
        {
          bonus: {
            weeklyEarned: 0
          }
        },
        { merge: true }
      );

    });

    await batch.commit();

    console.log("Weekly mission + bonus reset completed");

  }
);

function getCurrentWeekId() {
  const now = new Date();

  const year = now.getUTCFullYear();

  const firstDay = new Date(Date.UTC(year, 0, 1));
  const days = Math.floor((now - firstDay) / (24 * 60 * 60 * 1000));

  const week = Math.ceil((days + firstDay.getUTCDay() + 1) / 7);

  return `${year}-W${week}`;
}

exports.detectVpnOnLogin = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after.lastIp) return;

    // Prevent repeated checks
    if (before.lastIp === after.lastIp) return;

    const ip = after.lastIp;

    try {
      const res = await axios.get(
        `https://proxycheck.io/v2/${ip}?vpn=1&risk=1`
      );

      const result = res.data[ip];

      const isVpn = result?.proxy === "yes";
      const risk = Number(result?.risk || 0);

      await event.data.after.ref.set(
        {
          fraud: {
            vpn: isVpn,
            vpnRisk: risk,
            isSuspicious: isVpn || risk > 70,
          },
        },
        { merge: true }
      );

      console.log("VPN check complete:", ip, isVpn);
    } catch (e) {
      console.log("VPN detection error", e);
    }
  }
);

exports.detectNetworkRisk = onDocumentCreated(
  {
    document: "users/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const userId = event.params.userId;
    const userRef = admin.firestore().collection("users").doc(userId);

    try {
      const userSnap = await userRef.get();
      if (!userSnap.exists) return;

      const userData = userSnap.data();
      const ip = userData.lastIp;

      if (!ip) {
        console.log("No IP found for user:", userId);
        return;
      }

      /// 🔥 Strong detection API
      const response = await axios.get(
        `http://ip-api.com/json/${ip}?fields=proxy,hosting,query`
      );

      const data = response.data;

      const isProxy = data.proxy === true;
      const isHosting = data.hosting === true;

      /// 🔥 TOR detection (extra)
      const torResponse = await axios.get(
        `https://check.torproject.org/exit-addresses`
      );

      const isTor = torResponse.data.includes(ip);

      const vpn = isProxy || isHosting || isTor;

      await userRef.set(
        {
          fraud: {
            vpn: vpn,
            proxy: isProxy,
            hosting: isHosting,
            tor: isTor,
            ipCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );

      console.log("Network fraud detection completed:", userId);
    } catch (e) {
      console.error("Network fraud error:", e);
    }
  }
);

exports.syncTermsVersion = onSchedule(
  {
    schedule: "every 1 hours",
    region: "us-central1",
  },
  async () => {
    try {
      // 🔥 Fetch live terms page
      const res = await axios.get(
        "https://quizzy2earn-ea152.web.app/terms.html"
      );

      const html = res.data;

      // 🔥 Extract version
      const match = html.match(
        /<meta name="terms-version" content="(.*?)"/
      );

      if (!match) {
        console.log("Terms version not found");
        return;
      }

      const version = match[1];

      const ref = admin
        .firestore()
        .collection("app_config")
        .doc("terms");

      const doc = await ref.get();

      const current = doc.data()?.currentVersion;

      if (current !== version) {
        await ref.set(
          {
            currentVersion: version,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        console.log("Terms version updated →", version);
      } else {
        console.log("No change in terms");
      }
    } catch (e) {
      console.error("Terms sync error", e);
    }
  }
);

exports.claimOneTimeReward = onCall(
  { region: "us-central1" },
  async (request) => {

    const uid = request.auth?.uid;
    const rewardType = request.data.rewardType;

    if (!uid) {
      throw new Error("Unauthenticated");
    }

    const userRef = admin.firestore().collection("users").doc(uid);

    return admin.firestore().runTransaction(async (tx) => {

      const snap = await tx.get(userRef);

      if (!snap.exists) {
        throw new Error("User not found");
      }

      const user = snap.data();

      let rewardCoins = 0;
      let fieldName = "";

      if (rewardType === "email") {

        if (!user.emailVerified) {
          throw new Error("Email not verified");
        }

        if (user.oneTimeRewards?.emailVerifiedRewardClaimed) {
          throw new Error("Already claimed");
        }

        rewardCoins = 100;
        fieldName = "oneTimeRewards.emailVerifiedRewardClaimed";

      }

      if (rewardType === "profile") {

        if (!user.profileSaved) {
          throw new Error("Profile not completed");
        }

        if (user.oneTimeRewards?.profileRewardClaimed) {
          throw new Error("Already claimed");
        }

        rewardCoins = 150;
        fieldName = "oneTimeRewards.profileRewardClaimed";

      }

      tx.update(userRef, {
        coinsAvailable: admin.firestore.FieldValue.increment(rewardCoins),
        [fieldName]: true
      });

      return {
        success: true,
        reward: rewardCoins
      };

    });

  }
);

exports.cpxPostback = onRequest(
  { region: "us-central1" },
  async (req, res) => {

    try {

      const status = req.query.status;
      const uid = req.query.user_id;
      const transId = req.query.trans_id;
      const amountUsd = Number(req.query.amount_usd || 0);
      const coins = Math.floor(Number(req.query.amount_local || 0));

      if (!uid || !transId) {
        return res.status(400).send("Missing parameters");
      }

      /// Only reward completed surveys
      if (status != 1) {
        return res.send("Ignored");
      }

      const db = admin.firestore();

      const userRef = db.collection("users").doc(uid);
      const txRef = db.collection("cpx_transactions").doc(transId);

      /// Prevent duplicate rewards
      const txSnap = await txRef.get();

      if (txSnap.exists) {
        console.log("Duplicate transaction:", transId);
        return res.send("Duplicate ignored");
      }

      /// Firestore transaction
      await db.runTransaction(async (tx) => {

        const userSnap = await tx.get(userRef);

        if (!userSnap.exists) {
          throw new Error("User not found");
        }

        /// Update user wallet
        tx.update(userRef, {
          coinsAvailable: admin.firestore.FieldValue.increment(coins),
          totalCoinsEarned: admin.firestore.FieldValue.increment(coins),
          "earnings.surveyCoins": admin.firestore.FieldValue.increment(coins)
        });

        /// Save transaction record (FINAL SCHEMA)
        tx.set(txRef, {
          uid: uid,
          transId: transId,
          coins: coins,
          amountUsd: amountUsd,
          source: "cpx",
          status: "completed",
          type: "survey",
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

      });

      console.log("CPX reward added:", uid, coins);

      return res.status(200).send("OK");

    } catch (e) {

      console.error("CPX error:", e);
      return res.status(500).send("ERROR");

    }

  }
);

exports.claimQuizReward = onCall(
  { region: "us-central1" },
  async (request) => {

    const uid = request.auth?.uid;
    const coins = Number(request.data.coins || 0);

    if (!uid) {
      throw new Error("Unauthenticated");
    }

    if (coins <= 0 || coins > 50) {
      throw new Error("Invalid reward");
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (tx) => {

      const snap = await tx.get(userRef);
      if (!snap.exists) throw new Error("User not found");

      tx.update(userRef, {
        coinsAvailable: admin.firestore.FieldValue.increment(coins),
        totalCoinsEarned: admin.firestore.FieldValue.increment(coins),
      });

      return { success: true };
    });
  }
);

exports.claimGameReward = onCall(
  { region: "us-central1" },
  async (request) => {

    const uid = request.auth?.uid;
    const coins = Number(request.data.coins || 0);
    const source = request.data.source || "game";

    if (!uid) throw new Error("Unauthenticated");

    if (coins <= 0 || coins > 100) {
      throw new Error("Invalid reward");
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (tx) => {

      const snap = await tx.get(userRef);
      if (!snap.exists) {
       throw new Error("User not found");
      }

      const userData = snap.data();

      const newBalance =
                (userData.coinsAvailable || 0) + coins;

      tx.update(userRef, {
        coinsAvailable: admin.firestore.FieldValue.increment(coins),
        totalCoinsEarned: admin.firestore.FieldValue.increment(coins),
      });

      /// 🔎 reward log (important for anti-fraud)
      const txRef = db.collection("wallet_transactions").doc();

      tx.set(txRef, {
        uid: uid,
        coins: coins,
        source: source,
        balanceAfter: newBalance,
        type: "reward",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    });
  }
);