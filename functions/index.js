const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

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
    const amount = Number(after.requestedAmount);

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
          coinsLocked: Math.max(coinsLocked - amount, 0),
        });
      }

      if (after.status === "rejected") {
        // ❌ REJECTED → return coins to available
        tx.update(userRef, {
          coinsAvailable: coinsAvailable + amount,
          coinsLocked: Math.max(coinsLocked - amount, 0),
        });
      }

      // 🔒 Mark as settled (VERY IMPORTANT)
      tx.update(withdrawRef, {
        coinsSettled: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

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
