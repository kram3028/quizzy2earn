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

    // Only run when status changes
    if (before.status === after.status) return;

    const userId = after.userId;
    const coinsUsed = Number(after.coinsUsed || 0);

    const userRef = admin.firestore().collection("users").doc(userId);
    const withdrawRef = event.data.after.ref;

    await admin.firestore().runTransaction(async (tx) => {

      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) return;

      // 🔥 PREVENT DOUBLE PROCESSING (BETTER CHECK)
      if (after.coinsSettled === true) return;

      if (after.status === "paid") {
        tx.update(userRef, {
          coinsLocked: admin.firestore.FieldValue.increment(-coinsUsed),
        });
      }

      if (after.status === "rejected") {
        tx.update(userRef, {
          coinsAvailable: admin.firestore.FieldValue.increment(coinsUsed),
          coinsLocked: admin.firestore.FieldValue.increment(-coinsUsed),
        });
      }

      // ✅ Mark settled AFTER wallet update
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

      //----------------------------------------------------
      // Apply debt recovery
      //----------------------------------------------------

      const debtResult =
          applyRewardWithDebtRecovery(
              user,
              reward
          );

      tx.update(userRef, {

        //--------------------------------------------------
        // Wallet
        //--------------------------------------------------

        coinsAvailable:
            debtResult.newWalletBalance,

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(reward),

        outstandingReversalDebt:
            debtResult.remainingDebt,

        //--------------------------------------------------
        // Weekly bonus tracking
        //--------------------------------------------------

        "bonus.weeklyEarned":
            admin.firestore.FieldValue.increment(reward),

        //--------------------------------------------------
        // Daily login
        //--------------------------------------------------

        "dailyLogin.streak":
            streak,

        "dailyLogin.lastClaim":
            now,

      });

      //----------------------------------------------------
      // Wallet history
      //----------------------------------------------------

      const walletRef = userRef
          .collection("wallet_transactions")
          .doc();

      tx.set(walletRef, {

        uid,

        coins: reward,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        source: "daily_login",

        type: "reward",

        balanceAfter:
            debtResult.newWalletBalance,

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

      });

      return {

        success: true,

        reward,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        streak,

      };
    });
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

      //----------------------------------------------------
      // Apply debt recovery
      //----------------------------------------------------

      const userData = userSnap.data();

      const reward = 100;

      const debtResult =
          applyRewardWithDebtRecovery(
              userData,
              reward
          );

      tx.update(userRef, {

        //--------------------------------------------------
        // Wallet
        //--------------------------------------------------

        coinsAvailable:
            debtResult.newWalletBalance,

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(reward),

        outstandingReversalDebt:
            debtResult.remainingDebt,

        //--------------------------------------------------
        // Mission earnings
        //--------------------------------------------------

        "earnings.missionCoins":
            admin.firestore.FieldValue.increment(reward),

      });

      //----------------------------------------------------
      // Wallet history
      //----------------------------------------------------

      const walletRef =
          userRef
              .collection("wallet_transactions")
              .doc();

      tx.set(walletRef, {

        uid: userRef.id,

        coins: reward,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        source: "daily_mission",

        type: "reward",

        balanceAfter:
            debtResult.newWalletBalance,

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

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
        "https://quizzy2earn-ea152.web.app/privacy.html"
      );

      const html = res.data;

      // 🔥 Extract version
      const match = html.match(
        /<meta name="privacy-version" content="(.*?)"/
      );

      if (!match) {
        console.log("Terms version not found");
        return;
      }

      const version = match[1];

      const ref = admin
        .firestore()
        .collection("app_config")
        .doc("privacy");

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

      //----------------------------------------------------
      // Apply debt recovery
      //----------------------------------------------------

      const debtResult =
          applyRewardWithDebtRecovery(
              user,
              rewardCoins
          );

      tx.update(userRef, {

        coinsAvailable:
            debtResult.newWalletBalance,

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(rewardCoins),

        outstandingReversalDebt:
            debtResult.remainingDebt,

        "earnings.oneTimeRewardCoins":
            admin.firestore.FieldValue.increment(rewardCoins),

        [fieldName]:
            true,

      });

      const walletRef =
          userRef
              .collection("wallet_transactions")
              .doc();

      tx.set(walletRef, {

        uid,

        coins: rewardCoins,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        source: rewardType,

        type: "one_time_reward",

        balanceAfter:
            debtResult.newWalletBalance,

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

      });

      return {

        success: true,

        reward: rewardCoins,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

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

        //----------------------------------------------------
        // Apply debt recovery
        //----------------------------------------------------

        const userData = userSnap.data();

        const debtResult =
            applyRewardWithDebtRecovery(
                userData,
                coins
            );

        tx.update(userRef, {

          //--------------------------------------------------
          // Wallet
          //--------------------------------------------------

          coinsAvailable:
              debtResult.newWalletBalance,

          //--------------------------------------------------
          // Lifetime earnings
          //--------------------------------------------------

          totalCoinsEarned:
              admin.firestore.FieldValue.increment(coins),

          //--------------------------------------------------
          // Survey earnings
          //--------------------------------------------------

          "earnings.surveyCoins":
              admin.firestore.FieldValue.increment(coins),

          //--------------------------------------------------
          // Remaining debt
          //--------------------------------------------------

          outstandingReversalDebt:
              debtResult.remainingDebt,

        });

        /// Save transaction record (FINAL SCHEMA)
        tx.set(txRef, {

          uid: uid,

          transId: transId,

          //--------------------------------------------------
          // Original reward
          //--------------------------------------------------

          coins: coins,

          //--------------------------------------------------
          // Actually credited
          //--------------------------------------------------

          creditedCoins:
              debtResult.creditedCoins,

          //--------------------------------------------------
          // Debt recovered
          //--------------------------------------------------

          debtRecovered:
              debtResult.debtPaid,

          //--------------------------------------------------
          // Remaining debt
          //--------------------------------------------------

          remainingDebt:
              debtResult.remainingDebt,

          amountUsd: amountUsd,

          source: "cpx",

          status: "completed",

          type: "survey",

          createdAt:
              admin.firestore.FieldValue.serverTimestamp(),

        });

        const walletRef = userRef
            .collection("wallet_transactions")
            .doc();

        tx.set(walletRef, {

          uid,

          coins,

          creditedCoins:
              debtResult.creditedCoins,

          debtRecovered:
              debtResult.debtPaid,

          remainingDebt:
              debtResult.remainingDebt,

          source: "cpx",

          type: "survey",

          balanceAfter:
              debtResult.newWalletBalance,

          transactionId:
              transId,

          createdAt:
              admin.firestore.FieldValue.serverTimestamp(),

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

      if (!snap.exists) {
        throw new Error("User not found");
      }

      const userData = snap.data();

      //----------------------------------------------------
      // Apply debt recovery
      //----------------------------------------------------

      const debtResult =
          applyRewardWithDebtRecovery(
              userData,
              coins
          );

      const newBalance =
          debtResult.newWalletBalance;

      tx.update(userRef, {

        //--------------------------------------------------
        // Wallet
        //--------------------------------------------------

        coinsAvailable:
            newBalance,

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(coins),

        outstandingReversalDebt:
            debtResult.remainingDebt,

      });

      //----------------------------------------------------
      // Wallet history
      //----------------------------------------------------

      const walletRef =
          userRef
              .collection("wallet_transactions")
              .doc();

      tx.set(walletRef, {

        uid,

        coins,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        source: "quiz",

        type: "reward",

        balanceAfter:
            debtResult.newWalletBalance,

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

      });

      return {

        success: true,

        reward: coins,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

      };
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

      //----------------------------------------------------
      // Apply debt recovery
      //----------------------------------------------------

      const debtResult =
          applyRewardWithDebtRecovery(
              userData,
              coins
          );

      const newBalance =
          debtResult.newWalletBalance;

      tx.update(userRef, {

        //--------------------------------------------------
        // Wallet
        //--------------------------------------------------

        coinsAvailable:
            newBalance,

        //--------------------------------------------------
        // Lifetime earnings
        //--------------------------------------------------

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(coins),

        //--------------------------------------------------
        // Outstanding reversal debt
        //--------------------------------------------------

        outstandingReversalDebt:
            debtResult.remainingDebt,

      });

      /// 🔎 reward log (important for anti-fraud)
      const txRef = db
        .collection("users")
        .doc(uid)
        .collection("wallet_transactions")
        .doc();

      tx.set(txRef, {

        uid: uid,

        //--------------------------------------------------
        // Original reward
        //--------------------------------------------------

        coins: coins,

        //--------------------------------------------------
        // Coins actually credited
        //--------------------------------------------------

        creditedCoins:
            debtResult.creditedCoins,

        //--------------------------------------------------
        // Debt paid
        //--------------------------------------------------

        debtRecovered:
            debtResult.debtPaid,

        //--------------------------------------------------
        // Remaining debt
        //--------------------------------------------------

        remainingDebt:
            debtResult.remainingDebt,

        source: source,

        balanceAfter:
            newBalance,

        type: "reward",

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

      });

      return { success: true };
    });
  }
);

exports.trackAdView = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new Error("Unauthenticated");

  const userRef = admin.firestore().collection("users").doc(uid);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const data = snap.data();

    const today = new Date().toISOString().split("T")[0];

    let adData = data.adWatch || {};

    if (adData.date !== today) {
      adData = { date: today, count: 0 };
    }

    // ❌ Limit per day
    if (adData.count >= 50) {
      throw new Error("Ad limit reached");
    }

    tx.update(userRef, {
      "adWatch.count": adData.count + 1,
      "adWatch.date": today,
    });
  });

  return { success: true };
});

exports.applyReferralCode = onCall(
  { region: "us-central1" },
  async (request) => {

    const uid = request.auth?.uid;
    const code = (request.data.code || "").toUpperCase().trim();

    if (!uid) throw new Error("Unauthenticated");
    if (!code) throw new Error("Code required");

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    return db.runTransaction(async (tx) => {

      // 🔹 GET USER
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new Error("User not found");

      const userData = userSnap.data();

      // 🚫 FRAUD BLOCK
      if (userData?.fraud?.isBlocked === true) {
        throw new Error("User blocked");
      }

      // 🚫 EMULATOR BLOCK (DISABLE FOR TEST IF NEEDED)
      if (userData?.deviceInfo?.isEmulator === true) {
        throw new Error("Emulator not allowed");
      }

      //⚠️ RATE LIMIT
      const now = Date.now();
      const lastAttempt = userData?.lastReferralAttempt || 0;

      if (now - lastAttempt < 5000) {
        throw new Error("Too many attempts");
      }

      // ❌ ALREADY USED
      if (userData.referredBy) {
        throw new Error("Referral already used");
      }

      // 🔹 GET REFERRAL CODE DOC
      const codeRef = db.collection("referral_codes").doc(code);
      const codeSnap = await tx.get(codeRef);

      if (!codeSnap.exists) {
        throw new Error("Invalid code");
      }

      const referrerId = codeSnap.data().uid;

      // ❌ SELF REFERRAL
      if (referrerId === uid) {
        throw new Error("Cannot use your own code");
      }

      // 🔹 GET REFERRER USER
      const referrerRef = db.collection("users").doc(referrerId);
      const referrerSnap = await tx.get(referrerRef);

      if (!referrerSnap.exists) {
        throw new Error("Referrer not found");
      }

      const referrerData = referrerSnap.data();

      // 🔒 SAME DEVICE BLOCK
      const userFingerprint = userData?.deviceInfo?.fingerprint;

      if (
        userFingerprint &&
        referrerData?.deviceInfo?.fingerprint === userFingerprint
      ) {
        throw new Error("Same device referral not allowed");
      }

      // ✅ APPLY REFERRAL TO USER
      tx.update(userRef, {
        referredBy: referrerId,
        referralUsedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastReferralAttempt: now,
      });

      // 🔥 SAVE REFERRAL TRACKING (NEW SYSTEM)
      const referralListRef = referrerRef
        .collection("referrals_list")
        .doc(uid);

      tx.set(referralListRef, {
        userId: uid,
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        quizCount: 0,
        activeDays: 0,
        totalCoins: 0,
        emailVerified: false,
        profileCompleted: false,
      }, { merge: true });

      // ✅ REFERRER SUBCOLLECTION (FIXED 🔥)
      const referrerReferralRef = referrerRef
        .collection("referral")
        .doc("main");

      tx.set(
        referrerReferralRef,
        {
          totalReferrals: admin.firestore.FieldValue.increment(1),
        }, { merge: true });

    });
  }
);

exports.onUserProfileCompleted = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
  },
  async (event) => {

    const before = event.data.before.data();
    const after = event.data.after.data();

    // ✅ Only for referred users
    if (!after.referredBy) return;

    // ✅ Prevent duplicate
    if (after.profileRewardGiven === true) return;

    const isCompleted =
      after.emailVerified === true &&
      after.profileSaved === true;

    if (!isCompleted) return;

    const referrerRef = admin.firestore()
      .collection("users")
      .doc(after.referredBy);

    const userRef = event.data.after.ref;
    let notificationToken = null;

    await admin.firestore().runTransaction(async (tx) => {

      // 🎯 GIVE REWARD ONLY TO USER A (REFERRER)
      //----------------------------------------------------
      // Apply debt recovery
      //----------------------------------------------------

      const referrerData =
          referrerSnap.data();

      const reward = 25;

      const debtResult =
          applyRewardWithDebtRecovery(
              referrerData,
              reward
          );

      tx.update(referrerRef, {

        coinsAvailable:
            debtResult.newWalletBalance,

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(reward),

        outstandingReversalDebt:
            debtResult.remainingDebt,

        "earnings.referralCoins":
            admin.firestore.FieldValue.increment(reward),

      });

      const walletRef =
          referrerRef
              .collection("wallet_transactions")
              .doc();

      tx.set(walletRef, {

        uid: after.referredBy,

        coins: reward,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        source: "referral_profile",

        type: "referral",

        balanceAfter:
            debtResult.newWalletBalance,

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

      });

      notificationToken =
          referrerSnap.data()?.fcmToken || null;

      // 🔥 SYNC PROFILE STATUS
      const referralRef = admin.firestore()
        .collection("users")
        .doc(after.referredBy)
        .collection("referrals_list")
        .doc(event.params.userId);

      tx.set(referralRef, {
        emailVerified: true,
        profileCompleted: true,
      }, { merge: true });

      // ✅ Mark processed (on user B)
      tx.update(userRef, {
        profileRewardGiven: true,
      });

    });

    //----------------------------------------------------
    // Send notification AFTER transaction commit
    //----------------------------------------------------

    if (notificationToken) {
      try {

        await admin.messaging().send({

          token: notificationToken,

          notification: {
            title: "🎉 Referral Reward",
            body: "Your referral completed profile & email. You earned 25 coins!",
          },

        });

      } catch (e) {
        console.error("FCM send failed:", e);
      }
    }

  }
);

exports.onQuizMilestone = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
  },
  async (event) => {

    const before = event.data.before.data();
    const after = event.data.after.data();

    const beforeQuiz = before.quizCount || 0;
    const afterQuiz = after.quizCount || 0;

    // ❌ No increase → ignore
    if (afterQuiz <= beforeQuiz) return;

    // 🎯 Only every 10 quizzes
    if (afterQuiz % 10 !== 0) return;

    // ❌ If not referred user → ignore
    if (!after.referredBy) return;

    const referrerRef = admin.firestore()
      .collection("users")
      .doc(after.referredBy);

    let notificationToken = null;

    await admin.firestore().runTransaction(async (tx) => {

      // ✅ GIVE REWARD TO USER A (REFERRER)
      const referrerSnap = await tx.get(referrerRef);

      const referrerData = referrerSnap.data();

      const reward = 10;

      const debtResult =
          applyRewardWithDebtRecovery(
              referrerData,
              reward
          );

      tx.update(referrerRef, {

        coinsAvailable:
            debtResult.newWalletBalance,

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(reward),

        outstandingReversalDebt:
            debtResult.remainingDebt,

        "earnings.referralCoins":
            admin.firestore.FieldValue.increment(reward),

      });

      const walletRef =
          referrerRef
              .collection("wallet_transactions")
              .doc();

      tx.set(walletRef, {

        uid: after.referredBy,

        coins: reward,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        source: "referral_quiz_milestone",

        type: "referral",

        balanceAfter:
            debtResult.newWalletBalance,

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

      });

      notificationToken =
          referrerSnap.data()?.fcmToken || null;

      // 🔥 SYNC QUIZ PROGRESS TO REFERRAL LIST
      const referralRef = admin.firestore()
        .collection("users")
        .doc(after.referredBy)
        .collection("referrals_list")
        .doc(event.params.userId);

      tx.set(referralRef, {
        quizCount: afterQuiz,
      }, { merge: true });

    });

    if (notificationToken) {
      try {

        await admin.messaging().send({

          token: notificationToken,

          notification: {
            title: "🎉 Referral Reward",
            body: "You earned 10 coins from referral!",
          },

        });

      } catch (e) {
        console.error("FCM send failed:", e);
      }
    }

  }
);

exports.onEarningMilestone = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
  },
  async (event) => {

    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after.referredBy) return;

    const beforeCoins = before.coinsAvailable || 0;
    const afterCoins = after.coinsAvailable || 0;

    const beforeMilestone = Math.floor(beforeCoins / 1000);
    const afterMilestone = Math.floor(afterCoins / 1000);

    if (afterMilestone <= beforeMilestone) return;

    const referrerRef = admin.firestore()
      .collection("users")
      .doc(after.referredBy);

    let notificationToken = null;

    await admin.firestore().runTransaction(async (tx) => {

      const referrerSnap = await tx.get(referrerRef);

      const referrerData = referrerSnap.data();

      const reward = 100;

      const debtResult =
          applyRewardWithDebtRecovery(
              referrerData,
              reward
          );

      tx.update(referrerRef, {

        coinsAvailable:
            debtResult.newWalletBalance,

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(reward),

        outstandingReversalDebt:
            debtResult.remainingDebt,

        "earnings.referralCoins":
            admin.firestore.FieldValue.increment(reward),

      });

      const walletRef =
          referrerRef
              .collection("wallet_transactions")
              .doc();

      tx.set(walletRef, {

        uid: after.referredBy,

        coins: reward,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        source: "referral_earning_milestone",

        type: "referral",

        balanceAfter:
            debtResult.newWalletBalance,

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

      });

      notificationToken =
          referrerSnap.data()?.fcmToken || null;

      // 🔥 SYNC EARNINGS PROGRESS
      const referralRef = admin.firestore()
        .collection("users")
        .doc(after.referredBy)
        .collection("referrals_list")
        .doc(event.params.userId);

      tx.set(referralRef, {
        totalCoins: after.coinsAvailable || 0,
      }, { merge: true });

    });

    if (notificationToken) {
      try {

        await admin.messaging().send({

          token: notificationToken,

          notification: {
            title: "💰 Big Reward!",
            body: "You earned 100 coins from referral milestone!",
          },

        });

      } catch (e) {
        console.error("FCM send failed:", e);
      }
    }

  }
);

exports.onActiveDaysMilestone = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
  },
  async (event) => {

    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after.referredBy) return;

    const beforeDays = before.activeDays || 0;
    const afterDays = after.activeDays || 0;

    if (afterDays < 3 || beforeDays >= 3) return;

    const referrerRef = admin.firestore()
      .collection("users")
      .doc(after.referredBy);

    let notificationToken = null;

    await admin.firestore().runTransaction(async (tx) => {

      const referrerSnap = await tx.get(referrerRef);

      const referrerData = referrerSnap.data();

      const reward = 25;

      const debtResult =
          applyRewardWithDebtRecovery(
              referrerData,
              reward
          );

      tx.update(referrerRef, {

        coinsAvailable:
            debtResult.newWalletBalance,

        totalCoinsEarned:
            admin.firestore.FieldValue.increment(reward),

        outstandingReversalDebt:
            debtResult.remainingDebt,

        "earnings.referralCoins":
            admin.firestore.FieldValue.increment(reward),

      });

      const walletRef =
          referrerRef
              .collection("wallet_transactions")
              .doc();

      tx.set(walletRef, {

        uid: after.referredBy,

        coins: reward,

        creditedCoins:
            debtResult.creditedCoins,

        debtRecovered:
            debtResult.debtPaid,

        remainingDebt:
            debtResult.remainingDebt,

        source: "referral_active_days",

        type: "referral",

        balanceAfter:
            debtResult.newWalletBalance,

        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),

      });

      notificationToken =
          referrerSnap.data()?.fcmToken || null;

      // 🔥 SYNC ACTIVE DAYS
      const referralRef = admin.firestore()
        .collection("users")
        .doc(after.referredBy)
        .collection("referrals_list")
        .doc(event.params.userId);

      tx.set(referralRef, {
        activeDays: after.activeDays || 0,
      }, { merge: true });

    });

    if (notificationToken) {
      try {

        await admin.messaging().send({

          token: notificationToken,

          notification: {
            title: "📅 Active Reward!",
            body: "Your referral stayed active 3 days!",
          },

        });

      } catch (e) {
        console.error("FCM send failed:", e);
      }
    }

  }
);

exports.syncReferralProgress = onDocumentUpdated(
  {
    document: "users/{userId}",
    region: "us-central1",
  },
  async (event) => {

    const after = event.data.after.data();

    // ❌ Not referred user → skip
    if (!after.referredBy) return;

    const referralRef = admin.firestore()
      .collection("users")
      .doc(after.referredBy)
      .collection("referrals_list")
      .doc(event.params.userId);

    await referralRef.set({
      quizCount: after.quizCount || 0,
      totalCoins: after.coinsAvailable || 0,
      activeDays: after.activeDays || 0,
    }, { merge: true });

  }
);

exports.createWithdrawRequestSecure = onCall(
  { region: "us-central1" },
  async (request) => {

    const uid = request.auth?.uid;
    const { amount, payoutMethod, payoutDetail } = request.data;

    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User not logged in"
      );
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    /// 🔹 GET COIN CONFIG
    const configSnap = await db.collection("app_config")
      .doc("coin_settings")
      .get();

    if (!configSnap.exists) {
      throw new functions.https.HttpsError("internal", "Config missing");
    }

    const coinValue = configSnap.data().coinValue || 0.8;
    const coinsRequired = Math.ceil(amount / coinValue);

    await db.runTransaction(async (tx) => {

      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new functions.https.HttpsError("not-found", "User not found");

      const data = userSnap.data();

      const available = data.coinsAvailable || 0;
      const locked = data.coinsLocked || 0;

      /// 🔒 SECURITY CHECKS
      if (locked > 0) {
        throw new functions.https.HttpsError("failed-precondition", "Pending withdraw exists");
      }

      if (available < coinsRequired) {
        throw new functions.https.HttpsError("failed-precondition", "Insufficient balance");
      }

      if (amount <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid amount");
      }

      /// 🔒 TERMS CHECK
      const termsSnap = await tx.get(
        db.collection("app_config").doc("privacy")
      );

      const termsVersion = termsSnap.data()?.currentVersion;

      if (
        data.agreedToTerms !== true ||
        data.agreedTermsVersion !== termsVersion
      ) {
        throw new functions.https.HttpsError("failed-precondition", "Accept latest terms");
      }

      /// 🔒 UPDATE WALLET (SAFE)
      tx.update(userRef, {
        coinsAvailable: available - coinsRequired,
        coinsLocked: locked + coinsRequired,
      });

      /// 🔥 CREATE WITHDRAW REQUEST
      const withdrawRef = db.collection("withdraw_requests").doc();

      tx.set(withdrawRef, {
        userId: uid,
        requestedAmount: amount,
        coinsUsed: coinsRequired,
        coinValue: coinValue,
        payoutMethod,
        payoutDetail,
        status: "pending",
        coinsSettled: false,
        rejectReason: "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAtLocal: Date.now(),
      });

    });

    return { success: true };
  }
);

const crypto = require("crypto");

function toBase64Url(buffer) {
  return buffer
      .toString("base64")
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "")
      .replace(/\n/g, "");
}

function verifyTheoremReachSignature(rawUrl, secretKey, receivedHash) {
  const hmac = crypto.createHmac("sha1", secretKey);
  hmac.update(rawUrl);

  const calculatedHash = toBase64Url(hmac.digest());

  return crypto.timingSafeEqual(
      Buffer.from(calculatedHash),
      Buffer.from(receivedHash)
  );
}

/**
 * Calculates how a reward should be split between
 * outstanding reversal debt and the user's wallet.
 *
 * Does NOT update Firestore.
 */
function applyRewardWithDebtRecovery(userData, rewardCoins) {

  const currentDebt =
      Number(userData.outstandingReversalDebt || 0);

  //----------------------------------------------------
  // No debt
  //----------------------------------------------------

  if (currentDebt <= 0) {

    return {

      creditedCoins: rewardCoins,

      debtPaid: 0,

      remainingDebt: 0,

      newWalletBalance:
          Number(userData.coinsAvailable || 0) + rewardCoins,

    };

  }

  //----------------------------------------------------
  // Reward pays debt first
  //----------------------------------------------------

  const debtPaid =
      Math.min(currentDebt, rewardCoins);

  const creditedCoins =
      rewardCoins - debtPaid;

  const remainingDebt =
      currentDebt - debtPaid;

  return {

    creditedCoins,

    debtPaid,

    remainingDebt,

    newWalletBalance:
        Number(userData.coinsAvailable || 0) + creditedCoins,

  };

}

exports.theoremReachPostback = onRequest(
  {
    region: "us-central1",

    secrets: ["THEOREMREACH_SECRET"],
    timeoutSeconds: 540,

  },
  async (req, res) => {

    try {

      console.log("========== THEOREMREACH CALLBACK ==========");

      if (req.method !== "GET") {
        return res.status(405).send("Method Not Allowed");
      }

      //----------------------------------------------------------------------
      // CHANGE THIS
      //----------------------------------------------------------------------
      // TEMPORARY - testing only
      const secretKey = process.env.THEOREMREACH_SECRET;
      // or use your existing configuration method if you've already stored it there
      //----------------------------------------------------------------------

      if (!secretKey) {
        console.error("Missing THEOREMREACH_SECRET");

        return res.status(500).send("Server configuration error");
      }

      //-------------------------------------------------------
      // Original URL exactly as received
      //-------------------------------------------------------

      const fullUrl =
          `${req.protocol}://${req.get("host")}${req.originalUrl}`;

      //-------------------------------------------------------
      // Extract received hash
      //-------------------------------------------------------

      const receivedHash = req.query.hash;

      if (!receivedHash) {
        return res.status(400).send("Missing hash");
      }

      //-------------------------------------------------------
      // Remove ONLY hash parameter
      // while preserving original parameter order
      //-------------------------------------------------------

      const rawUrl = fullUrl
          .replace(/[?&]hash=[^&]*/, "")
          .replace("?&", "?")
          .replace(/&$/, "");

      //-------------------------------------------------------
      // Verify signature
      //-------------------------------------------------------

      const valid = verifyTheoremReachSignature(
          rawUrl,
          secretKey,
          receivedHash
      );

      if (!valid) {

        console.error("Invalid TheoremReach signature");

        return res.status(403).send("Invalid signature");
      }

      console.log("Signature verified successfully");

      //-------------------------------------------------------
      // Read callback values
      //-------------------------------------------------------

      const {
        app_id,
        user_id,
        reward,
        currency,
        tx_id,
        screenout,
        profiler,
        reversal,
        offer_id,
        campaign_id,
        debug,
        ip,
      } = req.query;

      console.log({
        app_id,
        user_id,
        reward,
        currency,
        tx_id,
        screenout,
        profiler,
        reversal,
        offer_id,
        campaign_id,
        debug,
        ip,
      });

      //-------------------------------------------------------
      // Normalize reversal flag
      //-------------------------------------------------------

      const isReversal =
          String(reversal || "")
              .trim()
              .toLowerCase() === "true";

      //-------------------------------------------------------
      // Normalize callback flags
      //-------------------------------------------------------

      const isScreenout =
          String(screenout || "") === "1";

      const rewardCoins =
          Number(reward || 0);

      console.log({
        isReversal,
        isScreenout,
        rewardCoins,
      });

      console.log("Reversal:", isReversal);

      //-------------------------------------------------------
      // STEP 6.4
      // Reward Processing
      //-------------------------------------------------------

      const db = admin.firestore();

      const uid = String(user_id);
      const coins = rewardCoins;

      if (!Number.isFinite(coins) || coins < 0) {
        return res.status(400).send("Invalid reward");
      }

      if (!Number.isFinite(coins) || coins <= 0) {
        return res.status(400).send("Invalid reward");
      }

      const userRef =
          db.collection("users").doc(uid);

      const theoremTxRef =
          db.collection("theoremreach_transactions")
              .doc(String(tx_id));

      const walletRef =
          userRef
              .collection("wallet_transactions")
              .doc();

      //-------------------------------------------------------
      // No wallet update required
      //-------------------------------------------------------

      if (coins === 0 && !isReversal) {

        console.log(
            "Screen-out or informational callback (0 reward)."
        );

        await db.collection("theoremreach_transactions")
            .doc(String(tx_id))
            .set({

              uid,

              txId: String(tx_id),

              reward: 0,

              screenout: screenout || null,

              profiler: profiler || null,

              status: "screenout",

              processed: true,

              processedAt:
                  admin.firestore.FieldValue.serverTimestamp(),

            }, { merge: true });

        return res.status(200).send("OK");
      }

      await db.runTransaction(async (tx) => {

        //----------------------------------------------------
        // Duplicate protection
        //----------------------------------------------------

        const theoremTxSnap =
            await tx.get(theoremTxRef);

        const isReversal =
            String(reversal || "").toLowerCase() === "true";

        if (theoremTxSnap.exists) {

          const previous = theoremTxSnap.data();

          //--------------------------------------------------
          // Normal callback already processed
          //--------------------------------------------------

          if (!isReversal) {

            console.log(
              "Duplicate TheoremReach transaction:",
              tx_id
            );

            return;
          }

          //--------------------------------------------------
          // Already reversed
          //--------------------------------------------------

          if (previous.reversed === true) {

            console.log(
              "Transaction already reversed:",
              tx_id
            );

            return;
          }

        }

        //----------------------------------------------------
        // User
        //----------------------------------------------------

        const userSnap =
            await tx.get(userRef);

        if (!userSnap.exists) {
          throw new Error("User not found");
        }

        const userData = userSnap.data();

        //----------------------------------------------------
        // Current Wallet State
        //----------------------------------------------------

        const currentBalance =
            Number(userData.coinsAvailable || 0);

        const currentDebt =
            Number(userData.outstandingReversalDebt || 0);

        const newBalance =
            currentBalance + coins;

        //----------------------------------------------------
        // Reversal calculations
        //----------------------------------------------------

        let deductedCoins = 0;

        let remainingDebt = 0;

        let finalBalance = newBalance;

        //----------------------------------------------------
        // Update Wallet
        //----------------------------------------------------

        if (isReversal) {

          //--------------------------------------------------
          // Clamp balance at zero and record remaining debt
          //--------------------------------------------------

          deductedCoins =
              Math.min(currentBalance, coins);

          remainingDebt =
              coins - deductedCoins;

          finalBalance =
              currentBalance - deductedCoins;

          tx.update(userRef, {

            coinsAvailable:
                currentBalance - deductedCoins,

            "earnings.surveyCoins":
                admin.firestore.FieldValue.increment(-coins),

            outstandingReversalDebt:
                currentDebt + remainingDebt,

          });

        } else {

          //--------------------------------------------------
          // Normal reward
          //--------------------------------------------------

          finalBalance = newBalance;

          tx.update(userRef, {

            coinsAvailable:
                admin.firestore.FieldValue.increment(coins),

            totalCoinsEarned:
                admin.firestore.FieldValue.increment(coins),

            "earnings.surveyCoins":
                admin.firestore.FieldValue.increment(coins),

          });

        }

        //----------------------------------------------------
        // Wallet History
        //----------------------------------------------------

        tx.set(walletRef, {

          uid: uid,

          coins: isReversal ? -coins : coins,

          source: "theoremreach",

          type: isReversal ? "survey_reversal" : "survey",

          balanceAfter: finalBalance,

          deductedCoins:
              isReversal ? deductedCoins : null,

          outstandingDebtCreated:
              isReversal ? remainingDebt : null,

          transactionId: String(tx_id),

          offerId: offer_id || null,

          campaignId: campaign_id || null,

          createdAt:
              admin.firestore.FieldValue.serverTimestamp(),

        });

        //----------------------------------------------------
        // Transaction Log
        //----------------------------------------------------

        tx.set(theoremTxRef, {

          uid: uid,

          txId: String(tx_id),

          reward: coins,

          currency: currency || null,

          appId: app_id || null,

          offerId: offer_id || null,

          campaignId: campaign_id || null,

          status: isReversal
              ? "reversed"
              : (isScreenout && coins === 0)
                  ? "screenout"
                  : "completed",

          reversed: isReversal,

          reversedAt: isReversal
              ? admin.firestore.FieldValue.serverTimestamp()
              : null,

          screenout: screenout || null,

          profiler: profiler || null,

          processed: true,

          processedAt:
              admin.firestore.FieldValue.serverTimestamp(),

        }, { merge: true });

      });

      console.log(
          `TheoremReach reward credited: ${uid} +${coins}`
      );

      return res.status(200).send("OK");

    } catch (e) {

      console.error(e);

      return res.status(500).send("Internal Server Error");
    }
  }
);