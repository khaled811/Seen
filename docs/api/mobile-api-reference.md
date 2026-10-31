# Seen Business â€” agency (mobile) API reference

_Generated from `backend/schema.graphql`, the authorization matrix and the resolver docstrings. Seen-staff-only operations are left out on purpose; the hand-written guide is `mobile-api.md`._

**34 queries and 55 mutations.**

## Index

### Sign in, sign up and account recovery

| Operation | Kind | Who may call it |
|---|---|---|
| [`login`](#login) | Mutation | Public: no token needed |
| [`verifyOtp`](#verifyotp) | Mutation | Public: no token needed |
| [`refresh`](#refresh) | Mutation | Public: no token needed |
| [`logout`](#logout) | Mutation | Public: no token needed |
| [`registerMainAgent`](#registermainagent) | Mutation | Public: no token needed |
| [`verifyEmail`](#verifyemail) | Mutation | Public: no token needed |
| [`resendVerificationEmail`](#resendverificationemail) | Mutation | Public: no token needed |
| [`requestPasswordReset`](#requestpasswordreset) | Mutation | Public: no token needed |
| [`confirmPasswordReset`](#confirmpasswordreset) | Mutation | Public: no token needed |
| [`completeAccountSetup`](#completeaccountsetup) | Mutation | Public: no token needed |
| [`beginOtpEnrollment`](#beginotpenrollment) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`completeOtpEnrollment`](#completeotpenrollment) | Mutation | Public: no token needed |
| [`confirmEnrollmentCode`](#confirmenrollmentcode) | Mutation | Public: no token needed |
| [`confirmOtpEnrollment`](#confirmotpenrollment) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`regenerateRecoveryCodes`](#regeneraterecoverycodes) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`resetUser2fa`](#resetuser2fa) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`sendPasswordResetLink`](#sendpasswordresetlink) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |

### My profile

| Operation | Kind | Who may call it |
|---|---|---|
| [`me`](#me) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`updateMyProfile`](#updatemyprofile) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`changeMyPassword`](#changemypassword) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`requestEmailChange`](#requestemailchange) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`confirmEmailChange`](#confirmemailchange) | Mutation | Public: no token needed |
| [`setMyAvatar`](#setmyavatar) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`removeMyAvatar`](#removemyavatar) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |

### Home, notifications and ads

| Operation | Kind | Who may call it |
|---|---|---|
| [`portalHome`](#portalhome) | Query | Any agency user |
| [`portalAccount`](#portalaccount) | Query | Any agency user |
| [`agentDashboard`](#agentdashboard) | Query | Any agency user |
| [`portalNotifications`](#portalnotifications) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`notifications`](#notifications) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`markNotificationRead`](#marknotificationread) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`markAllNotificationsRead`](#markallnotificationsread) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`activeAds`](#activeads) | Query | Any agency user |
| [`recordAdImpression`](#recordadimpression) | Mutation | Any agency user |
| [`recordAdClick`](#recordadclick) | Mutation | Any agency user |

### Services and requests

| Operation | Kind | Who may call it |
|---|---|---|
| [`availableServices`](#availableservices) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`portalServiceCatalog`](#portalservicecatalog) | Query | Any agency user |
| [`prefillCandidates`](#prefillcandidates) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`prefillFromRequest`](#prefillfromrequest) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`createDraftRequest`](#createdraftrequest) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`addTraveler`](#addtraveler) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`batchAddTravelers`](#batchaddtravelers) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`portalDraftReview`](#portaldraftreview) | Query | Agency users holding permission `request.submit` |
| [`submitRequest`](#submitrequest) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`cancelRequest`](#cancelrequest) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`requests`](#requests) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`portalRequests`](#portalrequests) | Query | Any agency user |
| [`request`](#request) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`portalRequestTracking`](#portalrequesttracking) | Query | Any agency user |
| [`revealFieldValue`](#revealfieldvalue) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`documentDownloadUrl`](#documentdownloadurl) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`decideMainAgentApproval`](#decidemainagentapproval) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |

### Wallet and top-ups

| Operation | Kind | Who may call it |
|---|---|---|
| [`wallet`](#wallet) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`portalWallet`](#portalwallet) | Query | Any agency user |
| [`portalTopUpOptions`](#portaltopupoptions) | Query | Any agency user |
| [`paymentAccounts`](#paymentaccounts) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`requestTopUp`](#requesttopup) | Mutation | Agency users holding permission `wallet.topup.request` |
| [`submitTopUp`](#submittopup) | Mutation | Agency users holding permission `wallet.topup.request` |
| [`accountStatementPdf`](#accountstatementpdf) | Query | Agency users holding permission `data.export` |
| [`pendingSubAgentTopUps`](#pendingsubagenttopups) | Query | Agency users holding permission `wallet.topup.sub_agents` |
| [`approveSubAgentTopUp`](#approvesubagenttopup) | Mutation | Agency users holding permission `wallet.topup.sub_agents` |
| [`rejectSubAgentTopUp`](#rejectsubagenttopup) | Mutation | Agency users holding permission `wallet.topup.sub_agents` |
| [`topUpSubAgent`](#topupsubagent) | Mutation | Agency users holding permission `wallet.topup.sub_agents` |
| [`reclaimFromSubAgent`](#reclaimfromsubagent) | Mutation | Agency users holding permission `wallet.topup.sub_agents` |

### Agency team and sub-agents

| Operation | Kind | Who may call it |
|---|---|---|
| [`agentTree`](#agenttree) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`agentStaff`](#agentstaff) | Query | Agency users holding permission `staff.create` |
| [`portalAgents`](#portalagents) | Query | Agency users holding permission `request.view.agency` |
| [`createStaffUser`](#createstaffuser) | Mutation | Agency users holding permission `staff.create` |
| [`createBranch`](#createbranch) | Mutation | Agency users holding permission `staff.create` |
| [`createSubAgent`](#createsubagent) | Mutation | Agency users holding permission `agent.create_sub_agent` |
| [`updateUserRole`](#updateuserrole) | Mutation | Agency users holding permission `staff.create` |
| [`setAgentStatus`](#setagentstatus) | Mutation | Agency users holding permission `agent.create_sub_agent` |
| [`setAgentServiceEnablement`](#setagentserviceenablement) | Mutation | Agency users holding permission `pricing.set_margin` |
| [`updateAgentProfile`](#updateagentprofile) | Mutation | Agency users holding permission `agent.create_sub_agent` |

### Support

| Operation | Kind | Who may call it |
|---|---|---|
| [`tickets`](#tickets) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`ticket`](#ticket) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`ticketStats`](#ticketstats) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`ticketCategories`](#ticketcategories) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`unreadTicketsCount`](#unreadticketscount) | Query | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`openGeneralTicket`](#opengeneralticket) | Mutation | Agency users holding permission `ticket.general.create` |
| [`openWalletAdjustmentTicket`](#openwalletadjustmentticket) | Mutation | Agency users holding permission `ticket.wallet_adjustment.create` |
| [`replyTicket`](#replyticket) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`markTicketRead`](#markticketread) | Mutation | Any signed-in user (an agency user only ever sees their own agency's data) |
| [`rateTicket`](#rateticket) | Mutation | Agency users holding permission `ticket.general.create` |

### Reports

| Operation | Kind | Who may call it |
|---|---|---|
| [`agentReportCatalog`](#agentreportcatalog) | Query | Agency users holding permission `report.create` |
| [`runAgentReport`](#runagentreport) | Query | Agency users holding permission `report.create` |
| [`exportAgentReport`](#exportagentreport) | Query | Agency users holding permission `report.create` |

### Public information

| Operation | Kind | Who may call it |
|---|---|---|
| [`health`](#health) | Query | Public: no token needed |
| [`legalPage`](#legalpage) | Query | Public: no token needed |
| [`submitContactMessage`](#submitcontactmessage) | Mutation | Public: no token needed |

## Sign in, sign up and account recovery

### login

`mutation login(email: String!, password: String!, enrollmentLink: String = null): AuthResult!`

**Access:** Public: no token needed

| Argument | Type | Required | Default |
|---|---|---|---|
| `email` | `String!` | yes |  |
| `password` | `String!` | yes |  |
| `enrollmentLink` | `String` | no | `null` |

### verifyOtp

`mutation verifyOtp(challengeId: String!, code: String!): AuthResult!`

**Access:** Public: no token needed

| Argument | Type | Required | Default |
|---|---|---|---|
| `challengeId` | `String!` | yes |  |
| `code` | `String!` | yes |  |

### refresh

`mutation refresh: AuthResult!`

**Access:** Public: no token needed

Reads the httpOnly cookie directly (never a client-supplied argument — that would defeat the point of it being httpOnly). Added 2026-09-25 alongside the Vite migration: previously there was no consumer for the refresh cookie at all (a real, documented gap). Reuses SimpleJWT's own rotate-and-blacklist serializer rather than hand-rolling that logic, so it stays consistent with SIMPLE_JWT's ROTATE_REFRESH_TOKENS/BLACKLIST_AFTER_ROTATION settings.

### logout

`mutation logout: Boolean!`

**Access:** Public: no token needed

### registerMainAgent

`mutation registerMainAgent(input: MainAgentSignupInput!): Agent!`

**Access:** Public: no token needed

Open signup + Seen approval (BRD §2) — deliberately unauthenticated, matching registerMainAgent's doc comment. Always creates a Main Agent; approveAgent below is what actually activates it.

| Argument | Type | Required | Default |
|---|---|---|---|
| `input` | `MainAgentSignupInput!` | yes |  |

### verifyEmail

`mutation verifyEmail(token: String!): Boolean!`

**Access:** Public: no token needed

Deliberately unauthenticated: the link's token is the credential. Throttled against guessing.

| Argument | Type | Required | Default |
|---|---|---|---|
| `token` | `String!` | yes |  |

### resendVerificationEmail

`mutation resendVerificationEmail(email: String!, locale: String! = "ar"): Boolean!`

**Access:** Public: no token needed

Unauthenticated; always answers true so it cannot be used to find out which addresses are registered.

| Argument | Type | Required | Default |
|---|---|---|---|
| `email` | `String!` | yes |  |
| `locale` | `String!` | no | `"ar"` |

### requestPasswordReset

`mutation requestPasswordReset(email: String!, locale: String! = "ar"): Boolean!`

**Access:** Public: no token needed

Unauthenticated "forgot password". Always answers true (no account enumeration); throttled per IP and per address, every request counting, so it cannot be used to flood a mailbox. The link is the existing one-time reset token.

| Argument | Type | Required | Default |
|---|---|---|---|
| `email` | `String!` | yes |  |
| `locale` | `String!` | no | `"ar"` |

### confirmPasswordReset

`mutation confirmPasswordReset(uid: String!, token: String!, newPassword: String!): Boolean!`

**Access:** Public: no token needed

| Argument | Type | Required | Default |
|---|---|---|---|
| `uid` | `String!` | yes |  |
| `token` | `String!` | yes |  |
| `newPassword` | `String!` | yes |  |

### completeAccountSetup

`mutation completeAccountSetup(token: String!, newPassword: String!): Boolean!`

**Access:** Public: no token needed

Deliberately unauthenticated: the one-time link's token IS the credential (like confirmPasswordReset). Throttled against guessing.

| Argument | Type | Required | Default |
|---|---|---|---|
| `token` | `String!` | yes |  |
| `newPassword` | `String!` | yes |  |

### beginOtpEnrollment

`mutation beginOtpEnrollment(enrollmentToken: String = null): OtpEnrollmentResult!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

The enableOtp/QR-setup mutation flagged everywhere as "not yet built" — closed 2026-09-25. Requires an already-authenticated session (a user with otp_enabled=True but no confirmed device yet still logs in without a challenge, per login()'s own comment — that's exactly the state this lets them self-service out of). Never touches an existing CONFIRMED device — only clears a previous unconfirmed attempt, so this can't be used to silently swap out someone's already-active 2FA. SEC-03: also callable with the enrollment-scoped token login() returns to a user who has no device yet (and so no session).

| Argument | Type | Required | Default |
|---|---|---|---|
| `enrollmentToken` | `String` | no | `null` |

### completeOtpEnrollment

`mutation completeOtpEnrollment(enrollmentToken: String!, code: String!): AuthResult!`

**Access:** Public: no token needed

SEC-03: confirm the first device with the enrollment token; the real session is minted only now.

| Argument | Type | Required | Default |
|---|---|---|---|
| `enrollmentToken` | `String!` | yes |  |
| `code` | `String!` | yes |  |

### confirmEnrollmentCode

`mutation confirmEnrollmentCode(challengeId: String!, code: String!): AuthResult!`

**Access:** Public: no token needed

Guided re-enrolment, step 2: the code e-mailed at sign-in. Right code -> the enrollment-scoped token that opens the QR setup (never a session). Rate-limited per account and per address; a wrong code costs one of a few tries.

| Argument | Type | Required | Default |
|---|---|---|---|
| `challengeId` | `String!` | yes |  |
| `code` | `String!` | yes |  |

### confirmOtpEnrollment

`mutation confirmOtpEnrollment(code: String!): RecoveryCodesResult!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `code` | `String!` | yes |  |

### regenerateRecoveryCodes

`mutation regenerateRecoveryCodes(code: String!): RecoveryCodesResult!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

A new set of recovery codes (the old ones stop working). Needs a fresh valid app code: a stolen session alone must not be able to mint codes that outlive it.

| Argument | Type | Required | Default |
|---|---|---|---|
| `code` | `String!` | yes |  |

### resetUser2fa

`mutation resetUser2fa(userId: ID!, otpCode: String = null): Boolean!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

SEC-04. Seen staff's 2FA: superadmin only, never their own. An agent-side user's 2FA: their agency Owner or a superadmin, or the user themself with a fresh valid code. Out-of-scope targets look exactly like nonexistent ones.

| Argument | Type | Required | Default |
|---|---|---|---|
| `userId` | `ID!` | yes |  |
| `otpCode` | `String` | no | `null` |

### sendPasswordResetLink

`mutation sendPasswordResetLink(userId: ID!): Boolean!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

Seen (any user) or a Main Agent over their own agency's users (self, own staff, or own sub-agent's users) — never an arbitrary account. Console email backend locally, per settings.EMAIL_BACKEND's own comment — nothing external happens in dev/test.

| Argument | Type | Required | Default |
|---|---|---|---|
| `userId` | `ID!` | yes |  |

## My profile

### me

`query me: User!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

### updateMyProfile

`mutation updateMyProfile(fullName: String = null, phone: String = null): User!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

Any signed-in person: their own name and phone (audited by field name only).

| Argument | Type | Required | Default |
|---|---|---|---|
| `fullName` | `String` | no | `null` |
| `phone` | `String` | no | `null` |

### changeMyPassword

`mutation changeMyPassword(currentPassword: String!, newPassword: String!): Boolean!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

Needs the CURRENT password (throttled), runs the password rules, then signs every session out.

| Argument | Type | Required | Default |
|---|---|---|---|
| `currentPassword` | `String!` | yes |  |
| `newPassword` | `String!` | yes |  |

### requestEmailChange

`mutation requestEmailChange(newEmail: String!, currentPassword: String!, locale: String! = "ar"): Boolean!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

Needs the current password; a one-time link goes to the NEW address. Always true (nothing is revealed about taken addresses).

| Argument | Type | Required | Default |
|---|---|---|---|
| `newEmail` | `String!` | yes |  |
| `currentPassword` | `String!` | yes |  |
| `locale` | `String!` | no | `"ar"` |

### confirmEmailChange

`mutation confirmEmailChange(token: String!): Boolean!`

**Access:** Public: no token needed

Public: the link's token is the credential. Throttled against guessing.

| Argument | Type | Required | Default |
|---|---|---|---|
| `token` | `String!` | yes |  |

### setMyAvatar

`mutation setMyAvatar(fileId: ID!): User!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `fileId` | `ID!` | yes |  |

### removeMyAvatar

`mutation removeMyAvatar: User!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

## Home, notifications and ads

### portalHome

`query portalHome(servicesLimit: Int! = 6, recentLimit: Int! = 5): PortalHome!`

**Access:** Any agency user

Figma 05: everything the home screen shows in one round trip. Agent-side callers only; every list is inside the caller's own scope. (A promotional banner has no storage yet: see the report.)

| Argument | Type | Required | Default |
|---|---|---|---|
| `servicesLimit` | `Int!` | no | `6` |
| `recentLimit` | `Int!` | no | `5` |

### portalAccount

`query portalAccount: PortalAccount!`

**Access:** Any agency user

Figma 14 (and the pending state of 16 for an agency that can still sign in): the agency profile, the signed-in person, the security entry points and which menu rows this caller sees. (A PENDING agency cannot sign in at all: login answers `agency_pending`; the waiting screen is shown from that code.)

### agentDashboard

`query agentDashboard: AgentDashboard!`

**Access:** Any agency user

### portalNotifications

`query portalNotifications(unreadOnly: Boolean! = false, limit: Int! = 30, offset: Int! = 0): PortalNotificationList!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

Figma 17: the caller's own notifications, newest first, each with a kind / tone / icon and the request or amount it is about (only objects in the caller's scope), a `group` (today / yesterday / earlier) and the read state, plus the unread count.

| Argument | Type | Required | Default |
|---|---|---|---|
| `unreadOnly` | `Boolean!` | no | `false` |
| `limit` | `Int!` | no | `30` |
| `offset` | `Int!` | no | `0` |

### notifications

`query notifications(unreadOnly: Boolean! = false, limit: Int! = 100, offset: Int! = 0): [Notification!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `unreadOnly` | `Boolean!` | no | `false` |
| `limit` | `Int!` | no | `100` |
| `offset` | `Int!` | no | `0` |

### markNotificationRead

`mutation markNotificationRead(notificationId: ID!): Boolean!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `notificationId` | `ID!` | yes |  |

### markAllNotificationsRead

`mutation markAllNotificationsRead: Int!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

Figma 17 'mark all read': every unread notification of the CALLER (never anyone else's). Returns how many were marked.

### activeAds

`query activeAds(placement: String = null, locale: String = null): [AgentAd!]!`

**Access:** Any agency user

The ads the caller's agency may see right now (agent-side users). `placement` home_banner|requests_banner|wallet_banner (omitted = every slot, at most three each); `locale` ar|en picks the language of title / body / ctaLabel (the other language is the fallback). A pending or suspended agency gets an empty list.

| Argument | Type | Required | Default |
|---|---|---|---|
| `placement` | `String` | no | `null` |
| `locale` | `String` | no | `null` |

### recordAdImpression

`mutation recordAdImpression(adId: ID!): Boolean!`

**Access:** Any agency user

Count that the caller's agency screen showed this ad (agent-side users). Once per ad per person per day; returns whether it was counted. Only an ad the agency may currently see counts (anything else is ad_not_found). Stores no person or agency.

| Argument | Type | Required | Default |
|---|---|---|---|
| `adId` | `ID!` | yes |  |

### recordAdClick

`mutation recordAdClick(adId: ID!): Boolean!`

**Access:** Any agency user

Count a click on the ad's button (agent-side users). At most one per ad per person per 10 minutes.

| Argument | Type | Required | Default |
|---|---|---|---|
| `adId` | `ID!` | yes |  |

## Services and requests

### availableServices

`query availableServices(agentId: ID = null): [ServiceType!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `agentId` | `ID` | no | `null` |

### portalServiceCatalog

`query portalServiceCatalog(search: String = null): PortalCatalog!`

**Access:** Any agency user

Figma 08: the services this agency may order, grouped by category, with price / service time / icon key. Same visibility rule as availableServices (active, enabled for the agency and inherited down the tree).

| Argument | Type | Required | Default |
|---|---|---|---|
| `search` | `String` | no | `null` |

### prefillCandidates

`query prefillCandidates(serviceTypeId: ID!, agentId: ID = null): [PrefillCandidate!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

Earlier requests the caller may copy details FROM when filing `service_type_id` (an admin-set rule, e.g. the airline circular from its approval). Newest first, at most 20, no personal data. Scoped like every request read; nothing outside the caller's own agency (or the agency they file for) is ever listed.

| Argument | Type | Required | Default |
|---|---|---|---|
| `serviceTypeId` | `ID!` | yes |  |
| `agentId` | `ID` | no | `null` |

### prefillFromRequest

`mutation prefillFromRequest(serviceTypeId: ID!, sourceRequestId: ID!, agentId: ID = null): PrefillResult!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

The mapped values of one earlier request, to pre-fill a new one. The clear text of the caller's own earlier entries (sensitive fields included), so it is treated like `revealFieldValue`: authenticated -> the source inside the caller's scope and offered by an admin rule (else "not found") -> throttled -> audited BEFORE the values leave (ids and counts only) -> suggestions only: nothing is saved here.

| Argument | Type | Required | Default |
|---|---|---|---|
| `serviceTypeId` | `ID!` | yes |  |
| `sourceRequestId` | `ID!` | yes |  |
| `agentId` | `ID` | no | `null` |

### createDraftRequest

`mutation createDraftRequest(serviceTypeId: ID!, agentId: ID = null): Request!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `serviceTypeId` | `ID!` | yes |  |
| `agentId` | `ID` | no | `null` |

### addTraveler

`mutation addTraveler(requestId: ID!, fieldValues: [FieldValueInput!]!): RequestTraveler!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `requestId` | `ID!` | yes |  |
| `fieldValues` | `[FieldValueInput!]!` | yes |  |

### batchAddTravelers

`mutation batchAddTravelers(requestId: ID!, travelers: [BatchTravelerInput!]!): [RequestTraveler!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `requestId` | `ID!` | yes |  |
| `travelers` | `[BatchTravelerInput!]!` | yes |  |

### portalDraftReview

`query portalDraftReview(requestId: ID!): PortalDraftReview!`

**Access:** Agency users holding permission `request.submit`

Figma 10: the review step of a draft: service, travelers, the quote (price x travelers, what is left after the hold), and the reasons it cannot be submitted yet. Reads the draft the caller owns (their own submission, or the scope they manage).

| Argument | Type | Required | Default |
|---|---|---|---|
| `requestId` | `ID!` | yes |  |

### submitRequest

`mutation submitRequest(requestId: ID!): Request!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `requestId` | `ID!` | yes |  |

### cancelRequest

`mutation cancelRequest(requestId: ID!, reason: String! = ""): CancelledRequest!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `requestId` | `ID!` | yes |  |
| `reason` | `String!` | no | `""` |

### requests

`query requests(status: String = null, search: String = null, assignedProcessorId: ID = null, unassigned: Boolean = null, serviceTypeId: ID = null, agentId: ID = null, isBreached: Boolean = null, limit: Int! = 200, offset: Int! = 0): [Request!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `status` | `String` | no | `null` |
| `search` | `String` | no | `null` |
| `assignedProcessorId` | `ID` | no | `null` |
| `unassigned` | `Boolean` | no | `null` |
| `serviceTypeId` | `ID` | no | `null` |
| `agentId` | `ID` | no | `null` |
| `isBreached` | `Boolean` | no | `null` |
| `limit` | `Int!` | no | `200` |
| `offset` | `Int!` | no | `0` |

### portalRequests

`query portalRequests(group: String! = "all", search: String = null, agentId: ID = null, limit: Int! = 20, offset: Int! = 0): PortalRequestList!`

**Access:** Any agency user

Figma 06 / 18: the caller's requests as cards, newest first, with the chip counts, the documents banner and the empty-state flag. group: all | new | processing | action_needed | completed | closed | draft (`all` leaves drafts out). `search` matches the reference, the agency name and non-sensitive traveler values (never personal data). `agentId` narrows a Main Agent's view to one sub-agency (still inside its scope).

| Argument | Type | Required | Default |
|---|---|---|---|
| `group` | `String!` | no | `"all"` |
| `search` | `String` | no | `null` |
| `agentId` | `ID` | no | `null` |
| `limit` | `Int!` | no | `20` |
| `offset` | `Int!` | no | `0` |

### request

`query request(id: ID!): Request`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `id` | `ID!` | yes |  |

### portalRequestTracking

`query portalRequestTracking(id: ID!): PortalRequestTracking`

**Access:** Any agency user

Figma 07: the status timeline (with the moment each stage was reached), the countdown, the information request, the delivered result and the actions available now. null when the request does not exist OR is outside the caller's scope (indistinguishable).

| Argument | Type | Required | Default |
|---|---|---|---|
| `id` | `ID!` | yes |  |

### revealFieldValue

`mutation revealFieldValue(fieldValueId: ID!): String!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

SEC-20: the clear text of one sensitive field. Authenticated -> the value's request INSIDE the caller's scope (out of scope == not found) -> a permission to work on requests (agents: their own scope) -> audit BEFORE the value leaves -> throttled. The value never appears in the audit row.

| Argument | Type | Required | Default |
|---|---|---|---|
| `fieldValueId` | `ID!` | yes |  |

### documentDownloadUrl

`mutation documentDownloadUrl(fileId: ID!): DownloadUrl!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

SEC-19: authenticate -> find the file's request INSIDE the caller's scope (out of scope == not found) -> audit -> a signed link of about 90 seconds. Nothing permanent is ever returned or stored.

| Argument | Type | Required | Default |
|---|---|---|---|
| `fileId` | `ID!` | yes |  |

### decideMainAgentApproval

`mutation decideMainAgentApproval(requestId: ID!, approve: Boolean!, note: String! = ""): Request!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

The Sub-Agent's own Main Agent, acting as its manager, deciding a request pending its approval — before it ever reaches Seen's own management-approval queue (2026-09-25 product decision, see decide_main_agent_approval's own docstring in apps.requests.services). No dedicated permission code exists for this (same documented-gap pattern as assignProcessor/ auditLog) — restricted here to a Staff/Branch-Manager/Owner user of exactly the Sub-Agent's parent Main Agent, never Seen staff and never an unrelated agent.

| Argument | Type | Required | Default |
|---|---|---|---|
| `requestId` | `ID!` | yes |  |
| `approve` | `Boolean!` | yes |  |
| `note` | `String!` | no | `""` |

## Wallet and top-ups

### wallet

`query wallet: Wallet!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

### portalWallet

`query portalWallet(filter: String! = "all", type: String = null, dateFrom: Date = null, dateTo: Date = null, agentId: ID = null, limit: Int! = 30, offset: Int! = 0): PortalWallet!`

**Access:** Any agency user

Figma 11: balance / held / credit line, the top-ups still waiting for Seen, and the statement of posted movements (newest first, with the balance after each, a `day` to group by). filter: all | debit | credit. `type` narrows to one transaction type. `agentId` lets a Main Agent read one of its own sub-agencies' wallet (anything else is 'not found'). Needs `pricing.view`, and is refused to a user limited to one branch (the figures are the whole agency's).

| Argument | Type | Required | Default |
|---|---|---|---|
| `filter` | `String!` | no | `"all"` |
| `type` | `String` | no | `null` |
| `dateFrom` | `Date` | no | `null` |
| `dateTo` | `Date` | no | `null` |
| `agentId` | `ID` | no | `null` |
| `limit` | `Int!` | no | `30` |
| `offset` | `Int!` | no | `0` |

### portalTopUpOptions

`query portalTopUpOptions: PortalTopUpOptions!`

**Access:** Any agency user

Figma 12: what the top-up screen needs: the payment accounts to pay into (active only), the methods, the minimum amount, how to attach the transfer receipt, and how many top-ups are already waiting. Submit with submitTopUp.

### paymentAccounts

`query paymentAccounts(includeInactive: Boolean! = false): [PaymentAccount!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `includeInactive` | `Boolean!` | no | `false` |

### requestTopUp

`mutation requestTopUp(amount: Decimal!, method: String!, referenceNumber: String! = "", idempotencyKey: String = null): Transaction!`

**Access:** Agency users holding permission `wallet.topup.request`

| Argument | Type | Required | Default |
|---|---|---|---|
| `amount` | `Decimal!` | yes |  |
| `method` | `String!` | yes |  |
| `referenceNumber` | `String!` | no | `""` |
| `idempotencyKey` | `String` | no | `null` |

### submitTopUp

`mutation submitTopUp(amount: Decimal!, method: String!, referenceNumber: String! = "", paymentAccountId: ID = null, receiptFileId: ID = null, idempotencyKey: String = null): SubmittedTopUp!`

**Access:** Agency users holding permission `wallet.topup.request`

requestTopUp plus the rest of the payment details (Figma mobile 12): the Seen account paid into and the transfer receipt (a file the caller uploaded through the upload endpoint). Same rules as requestTopUp: agent-side, wallet.topup.request, an idempotency key, a pending request only (no money moves until Seen approves it).

| Argument | Type | Required | Default |
|---|---|---|---|
| `amount` | `Decimal!` | yes |  |
| `method` | `String!` | yes |  |
| `referenceNumber` | `String!` | no | `""` |
| `paymentAccountId` | `ID` | no | `null` |
| `receiptFileId` | `ID` | no | `null` |
| `idempotencyKey` | `String` | no | `null` |

### accountStatementPdf

`query accountStatementPdf(dateFrom: Date!, dateTo: Date!, agentId: ID = null, language: String! = "en"): StatementPdf!`

**Access:** Agency users holding permission `data.export`

The account statement of ONE agency for a chosen period, as a PDF (BRD chapter 6). Audience: Seen staff holding wallet.view AND data.export (any agency; agentId required), or an agency user holding data.export (its own agency, or a sub-agency of it, never anyone else's: an agency outside that reach is "not found"). Audited on every export.

| Argument | Type | Required | Default |
|---|---|---|---|
| `dateFrom` | `Date!` | yes |  |
| `dateTo` | `Date!` | yes |  |
| `agentId` | `ID` | no | `null` |
| `language` | `String!` | no | `"en"` |

### pendingSubAgentTopUps

`query pendingSubAgentTopUps: [Transaction!]!`

**Access:** Agency users holding permission `wallet.topup.sub_agents`

### approveSubAgentTopUp

`mutation approveSubAgentTopUp(transactionId: ID!): Transaction!`

**Access:** Agency users holding permission `wallet.topup.sub_agents`

A Sub-Agent's own requestTopUp — decided by its Main Agent, never Seen (2026-09-25: "a sub agent ... asks his main agent, not seen accounts"). Funds itself out of the Main Agent's own wallet, same strict "never more than they actually have" rule as topUpSubAgent.

| Argument | Type | Required | Default |
|---|---|---|---|
| `transactionId` | `ID!` | yes |  |

### rejectSubAgentTopUp

`mutation rejectSubAgentTopUp(transactionId: ID!, note: String! = ""): Transaction!`

**Access:** Agency users holding permission `wallet.topup.sub_agents`

| Argument | Type | Required | Default |
|---|---|---|---|
| `transactionId` | `ID!` | yes |  |
| `note` | `String!` | no | `""` |

### topUpSubAgent

`mutation topUpSubAgent(subAgentId: ID!, amount: Decimal!, note: String! = "", idempotencyKey: String = null): Wallet!`

**Access:** Agency users holding permission `wallet.topup.sub_agents`

graphql-schema.md: "internal transfer, no Seen approval needed" — IT-13055's previously flagged gap, resolved 2026-09-25: the Main Agent funds a Sub-Agent purely out of their OWN wallet balance (apps.wallets.services.transfer_to_sub_agent respects main_wallet's own credit_limit on the debit leg — this is not a Seen credit line, unlike requestTopUp), and only within their own agency (never an arbitrary agent).

| Argument | Type | Required | Default |
|---|---|---|---|
| `subAgentId` | `ID!` | yes |  |
| `amount` | `Decimal!` | yes |  |
| `note` | `String!` | no | `""` |
| `idempotencyKey` | `String` | no | `null` |

### reclaimFromSubAgent

`mutation reclaimFromSubAgent(subAgentId: ID!, amount: Decimal!, note: String! = "", idempotencyKey: String = null): Wallet!`

**Access:** Agency users holding permission `wallet.topup.sub_agents`

The reverse of topUpSubAgent — debiting a Sub-Agent's own wallet back to its Main Agent's (2026-09-25 agent control panel "credit and debit money" gap). Same permission and own-agency scope as topUpSubAgent.

| Argument | Type | Required | Default |
|---|---|---|---|
| `subAgentId` | `ID!` | yes |  |
| `amount` | `Decimal!` | yes |  |
| `note` | `String!` | no | `""` |
| `idempotencyKey` | `String` | no | `null` |

## Agency team and sub-agents

### agentTree

`query agentTree(rootAgentId: ID = null): [Agent!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `rootAgentId` | `ID` | no | `null` |

### agentStaff

`query agentStaff: [User!]!`

**Access:** Agency users holding permission `staff.create`

### portalAgents

`query portalAgents(status: String! = "all", search: String = null, limit: Int! = 50, offset: Int! = 0): PortalAgents!`

**Access:** Agency users holding permission `request.view.agency`

Figma 13: the caller's own sub-agencies (a Main Agent; a Sub-Agent gets an empty list) with request counts, balance, status and the quick-action flags, plus the header figures. status: all | active | suspended | pending.

| Argument | Type | Required | Default |
|---|---|---|---|
| `status` | `String!` | no | `"all"` |
| `search` | `String` | no | `null` |
| `limit` | `Int!` | no | `50` |
| `offset` | `Int!` | no | `0` |

### createStaffUser

`mutation createStaffUser(input: StaffUserInput!): User!`

**Access:** Agency users holding permission `staff.create`

| Argument | Type | Required | Default |
|---|---|---|---|
| `input` | `StaffUserInput!` | yes |  |

### createBranch

`mutation createBranch(agentId: ID!, name: String!): Branch!`

**Access:** Agency users holding permission `staff.create`

| Argument | Type | Required | Default |
|---|---|---|---|
| `agentId` | `ID!` | yes |  |
| `name` | `String!` | yes |  |

### createSubAgent

`mutation createSubAgent(input: SubAgentInput!): Agent!`

**Access:** Agency users holding permission `agent.create_sub_agent`

| Argument | Type | Required | Default |
|---|---|---|---|
| `input` | `SubAgentInput!` | yes |  |

### updateUserRole

`mutation updateUserRole(userId: ID!, position: String!, branchId: ID = null): User!`

**Access:** Agency users holding permission `staff.create`

Reassign an existing seeded (user_type, position) role — picks from Role rows that already exist, never creates a new permission-template role. Agent side: staff.create holders, inside their own agency, only for users strictly below their own position and only to a position strictly below it (so nobody can demote an Owner, promote a peer, or leave an agency ownerless). Seen employees: Superadmin only. Out-of-scope targets look nonexistent.

| Argument | Type | Required | Default |
|---|---|---|---|
| `userId` | `ID!` | yes |  |
| `position` | `String!` | yes |  |
| `branchId` | `ID` | no | `null` |

### setAgentStatus

`mutation setAgentStatus(agentId: ID!, status: String!, cascadeToSubAgents: Boolean = true, reactivateCascaded: Boolean = true): Agent!`

**Access:** Agency users holding permission `agent.create_sub_agent`

Activate/deactivate (2026-09-25 agent control panel gap), plus self-approving a pending Sub-Agent straight out of the box (2026-09-26 clarification — see apps.agents.services.set_agent_status's own docstring for why) — Seen (any agent) or a Main Agent over their own Sub-Agent only, never a Sub-Agent's own staff or a sibling agency. B-14: when Seen suspends a Main Agent, `cascadeToSubAgents` (default true) also suspends its active Sub-Agents; when Seen reactivates it, `reactivateCascaded` (default true) brings back the ones that cascade suspended. Both are ignored for any other call. B-09: a suspension made by Seen can be lifted by Seen only (`suspended_by_seen`).

| Argument | Type | Required | Default |
|---|---|---|---|
| `agentId` | `ID!` | yes |  |
| `status` | `String!` | yes |  |
| `cascadeToSubAgents` | `Boolean` | no | `true` |
| `reactivateCascaded` | `Boolean` | no | `true` |

### setAgentServiceEnablement

`mutation setAgentServiceEnablement(agentId: ID!, serviceTypeId: ID!, enabled: Boolean!, overridePrice: Decimal = null, markupPercent: Decimal = null): Boolean!`

**Access:** Agency users holding permission `pricing.set_margin`

Turn a service on or off for one agency and set its margin: a fixed price OR a percentage (never both; neither clears it back to the tier price). A Main Agent does this for its own sub-agencies and never below its own price; Seen staff with agent.manage may discount a Main Agent. Every change is audited with the old and new values.

| Argument | Type | Required | Default |
|---|---|---|---|
| `agentId` | `ID!` | yes |  |
| `serviceTypeId` | `ID!` | yes |  |
| `enabled` | `Boolean!` | yes |  |
| `overridePrice` | `Decimal` | no | `null` |
| `markupPercent` | `Decimal` | no | `null` |

### updateAgentProfile

`mutation updateAgentProfile(agentId: ID!, name: String = null, ownerFullName: String = null, ownerEmail: String = null): Agent!`

**Access:** Agency users holding permission `agent.create_sub_agent`

Name + the owner's login identity — deliberately never tier (Seen's own internal pricing/credit classification, an agent never chooses/sees it, same rule as AgentType.tier below). Seen (any agent) or a Main Agent over their own Sub-Agent, same scope as setAgentStatus above.

| Argument | Type | Required | Default |
|---|---|---|---|
| `agentId` | `ID!` | yes |  |
| `name` | `String` | no | `null` |
| `ownerFullName` | `String` | no | `null` |
| `ownerEmail` | `String` | no | `null` |

## Support

### tickets

`query tickets(status: String = null, category: String = null, priority: String = null, isEscalated: Boolean = null, search: String = null, assignedToMe: Boolean! = false, unassigned: Boolean! = false, team: String = null, overdue: Boolean! = false, openedBy: ID = null, audience: String = null, limit: Int! = 50, offset: Int! = 0): [Ticket!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `status` | `String` | no | `null` |
| `category` | `String` | no | `null` |
| `priority` | `String` | no | `null` |
| `isEscalated` | `Boolean` | no | `null` |
| `search` | `String` | no | `null` |
| `assignedToMe` | `Boolean!` | no | `false` |
| `unassigned` | `Boolean!` | no | `false` |
| `team` | `String` | no | `null` |
| `overdue` | `Boolean!` | no | `false` |
| `openedBy` | `ID` | no | `null` |
| `audience` | `String` | no | `null` |
| `limit` | `Int!` | no | `50` |
| `offset` | `Int!` | no | `0` |

### ticket

`query ticket(id: ID!): Ticket`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `id` | `ID!` | yes |  |

### ticketStats

`query ticketStats: TicketStats!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

### ticketCategories

`query ticketCategories(audience: String = null, includeInactive: Boolean! = false): [TicketCategory!]!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

Categories the caller may pick. Agents: active agent-usable general categories only. Seen staff: `audience` "internal" / "agent_visible" narrows to categories usable that way; include_inactive needs ticket.category.manage.

| Argument | Type | Required | Default |
|---|---|---|---|
| `audience` | `String` | no | `null` |
| `includeInactive` | `Boolean!` | no | `false` |

### unreadTicketsCount

`query unreadTicketsCount: Int!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

### openGeneralTicket

`mutation openGeneralTicket(subject: String!, description: String! = "", category: String! = "general", priority: String = null, relatedRequestId: ID = null, relatedRequestIds: [ID!] = null, attachmentFileId: ID = null): Ticket!`

**Access:** Agency users holding permission `ticket.general.create`

An agent-side user opens a ticket on their own agency (always agent-visible). Seen staff use openInternalTicket / openTicketOnBehalfOfAgent instead.

| Argument | Type | Required | Default |
|---|---|---|---|
| `subject` | `String!` | yes |  |
| `description` | `String!` | no | `""` |
| `category` | `String!` | no | `"general"` |
| `priority` | `String` | no | `null` |
| `relatedRequestId` | `ID` | no | `null` |
| `relatedRequestIds` | `[ID!]` | no | `null` |
| `attachmentFileId` | `ID` | no | `null` |

### openWalletAdjustmentTicket

`mutation openWalletAdjustmentTicket(agentId: ID!, action: String!, amount: Decimal!, reason: String!, idempotencyKey: String = null): Ticket!`

**Access:** Agency users holding permission `ticket.wallet_adjustment.create`

| Argument | Type | Required | Default |
|---|---|---|---|
| `agentId` | `ID!` | yes |  |
| `action` | `String!` | yes |  |
| `amount` | `Decimal!` | yes |  |
| `reason` | `String!` | yes |  |
| `idempotencyKey` | `String` | no | `null` |

### replyTicket

`mutation replyTicket(ticketId: ID!, message: String! = "", isInternalNote: Boolean! = false, attachmentFileId: ID = null): TicketMessage!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `ticketId` | `ID!` | yes |  |
| `message` | `String!` | no | `""` |
| `isInternalNote` | `Boolean!` | no | `false` |
| `attachmentFileId` | `ID` | no | `null` |

### markTicketRead

`mutation markTicketRead(ticketId: ID!): Boolean!`

**Access:** Any signed-in user (an agency user only ever sees their own agency's data)

| Argument | Type | Required | Default |
|---|---|---|---|
| `ticketId` | `ID!` | yes |  |

### rateTicket

`mutation rateTicket(ticketId: ID!, rating: Int!): TicketRatingResult!`

**Access:** Agency users holding permission `ticket.general.create`

An agency user rates how a resolved/closed support ticket was handled (1-5), once. Agency side only; needs the same code that lets them open tickets (ticket.general.create); the ticket must be inside their own agency's visible tickets.

| Argument | Type | Required | Default |
|---|---|---|---|
| `ticketId` | `ID!` | yes |  |
| `rating` | `Int!` | yes |  |

## Reports

### agentReportCatalog

`query agentReportCatalog: JSON!`

**Access:** Agency users holding permission `report.create`

The report builder for an agency: its own requests and (with the wallet permission) its own ledger.

### runAgentReport

`query runAgentReport(spec: JSON!, language: String! = "en"): ReportResult!`

**Access:** Agency users holding permission `report.create`

| Argument | Type | Required | Default |
|---|---|---|---|
| `spec` | `JSON!` | yes |  |
| `language` | `String!` | no | `"en"` |

### exportAgentReport

`query exportAgentReport(spec: JSON!, format: String! = "pdf", language: String! = "en"): ReportExport!`

**Access:** Agency users holding permission `report.create`

The agency's report as csv, xlsx or branded pdf (Seen violet band, agency name, "Seen Booking powered by Jubari Travel" at the foot). Needs report.create AND data.export, refuses more than 5,000 rows, audited like every export.

| Argument | Type | Required | Default |
|---|---|---|---|
| `spec` | `JSON!` | yes |  |
| `format` | `String!` | no | `"pdf"` |
| `language` | `String!` | no | `"en"` |

## Public information

### health

`query health: String!`

**Access:** Public: no token needed

### legalPage

`query legalPage(kind: String!): LegalPageType!`

**Access:** Public: no token needed

Deliberately public: the Terms and the Privacy policy must be readable before anyone signs up.

| Argument | Type | Required | Default |
|---|---|---|---|
| `kind` | `String!` | yes |  |

### submitContactMessage

`mutation submitContactMessage(input: ContactMessageInput!): Boolean!`

**Access:** Public: no token needed

Deliberately unauthenticated (the Contact page). Every attempt counts against the client's IP, so it cannot be used to fill the inbox or to mail-bomb the staff mailbox.

| Argument | Type | Required | Default |
|---|---|---|---|
| `input` | `ContactMessageInput!` | yes |  |

## Types

Fields are listed as returned by the schema. A field that is not meant for agency users is not documented (cost price, supplier, internal notes).

### Object types

#### Agent

| Field | Type |
|---|---|
| `id` | `ID!` |
| `name` | `String!` |
| `status` | `String!` |
| `isGuaranteed` | `Boolean!` |
| `parentAgent` | `Agent` |
| `branches` | `[Branch!]!` |
| `suspendedAt` | `DateTime` |
| `suspensionSource` | `String!` |
| `ownerEmailVerified` | `Boolean` |
| `tier` | `String` |
| `wallet` | `Wallet` |
| `users` | `[User!]!` |
| `serviceEnablements` | `[AgentServiceEnablement!]!` |

#### AgentAd

| Field | Type |
|---|---|
| `id` | `ID!` |
| `placement` | `String!` |
| `title` | `String!` |
| `body` | `String!` |
| `ctaLabel` | `String!` |
| `titleAr` | `String!` |
| `titleEn` | `String!` |
| `bodyAr` | `String!` |
| `bodyEn` | `String!` |
| `ctaLabelAr` | `String!` |
| `ctaLabelEn` | `String!` |
| `ctaLink` | `String!` |
| `imageUrl` | `String` |
| `imageUrlExpiresAt` | `DateTime` |

#### AgentDashboard

| Field | Type |
|---|---|
| `requestCountsByStatus` | `JSON!` |
| `wallet` | `Wallet` |
| `subAgentPerformance` | `JSON!` |
| `branchPerformance` | `JSON!` |

#### AgentServiceEnablement

| Field | Type |
|---|---|
| `id` | `ID!` |
| `serviceType` | `ServiceType!` |
| `enabled` | `Boolean!` |
| `overridePrice` | `Decimal` |
| `markupPercent` | `Decimal` |

#### AuthResult

| Field | Type |
|---|---|
| `accessToken` | `String` |
| `refreshToken` | `String` |
| `otpRequired` | `Boolean!` |
| `challengeId` | `String` |
| `enrollmentRequired` | `Boolean!` |
| `enrollmentToken` | `String` |
| `enrollmentCodeRequired` | `Boolean!` |
| `emailHint` | `String` |
| `recoveryCodes` | `[String!]` |

#### Branch

| Field | Type |
|---|---|
| `id` | `ID!` |
| `name` | `String!` |
| `manager` | `User` |

#### CancelledRequest

| Field | Type |
|---|---|
| `id` | `ID!` |
| `status` | `String!` |

#### DownloadUrl

| Field | Type |
|---|---|
| `url` | `String!` |
| `expiresAt` | `DateTime!` |

#### FieldValue

| Field | Type |
|---|---|
| `id` | `ID!` |
| `fieldDefinition` | `ServiceFieldDefinition!` |
| `value` | `String!` |
| `isMasked` | `Boolean!` |

#### LegalPageType

| Field | Type |
|---|---|
| `kind` | `String!` |
| `titleAr` | `String!` |
| `titleEn` | `String!` |
| `bodyAr` | `String!` |
| `bodyEn` | `String!` |
| `version` | `Int!` |
| `updatedAt` | `DateTime!` |

#### Notification

| Field | Type |
|---|---|
| `id` | `ID!` |
| `eventType` | `String!` |
| `payload` | `JSON!` |
| `readAt` | `DateTime` |
| `createdAt` | `DateTime!` |

#### OtpEnrollmentResult

| Field | Type |
|---|---|
| `secret` | `String!` |
| `provisioningUri` | `String!` |

#### PaymentAccount

| Field | Type |
|---|---|
| `id` | `ID!` |
| `kind` | `String!` |
| `title` | `String!` |
| `holder` | `String!` |
| `bankName` | `String!` |
| `accountNumber` | `String!` |
| `currency` | `String!` |
| `instructions` | `String!` |
| `isActive` | `Boolean!` |
| `displayOrder` | `Int!` |

#### PortalAccount

| Field | Type |
|---|---|
| `agency` | `PortalAgency!` |
| `user` | `PortalAccountUser!` |
| `menu` | `PortalAccountMenu!` |
| `unreadNotifications` | `Int!` |
| `appVersion` | `String` |

#### PortalAccountMenu

| Field | Type |
|---|---|
| `agencyDetails` | `Boolean!` |
| `profitMargin` | `Boolean!` |
| `usersAndPermissions` | `Boolean!` |
| `subAgents` | `Boolean!` |
| `notifications` | `Boolean!` |
| `support` | `Boolean!` |

#### PortalAccountUser

| Field | Type |
|---|---|
| `id` | `ID!` |
| `fullName` | `String!` |
| `email` | `String!` |
| `position` | `String` |
| `otpEnabled` | `Boolean!` |
| `twoFactorEnrolled` | `Boolean!` |
| `recoveryCodesRemaining` | `Int!` |

#### PortalAgency

| Field | Type |
|---|---|
| `id` | `ID!` |
| `name` | `String!` |
| `status` | `String!` |
| `isVerified` | `Boolean!` |
| `kind` | `String!` |
| `parentName` | `String` |
| `city` | `String!` |
| `licenseNumber` | `String!` |
| `memberSince` | `DateTime!` |
| `subAgentCount` | `Int!` |
| `userCount` | `Int!` |
| `branchCount` | `Int!` |

#### PortalAgents

| Field | Type |
|---|---|
| `items` | `[PortalSubAgent!]!` |
| `activeCount` | `Int!` |
| `totalCount` | `Int!` |
| `statusCounts` | `JSON!` |
| `monthMargin` | `Decimal` |
| `currency` | `String` |
| `canAdd` | `Boolean!` |
| `isMainAgent` | `Boolean!` |

#### PortalAttention

| Field | Type |
|---|---|
| `count` | `Int!` |
| `soonestRemainingSeconds` | `Int` |
| `soonestRequestId` | `ID` |

#### PortalCatalog

| Field | Type |
|---|---|
| `groups` | `[PortalCatalogGroup!]!` |
| `total` | `Int!` |
| `canSubmit` | `Boolean!` |

#### PortalCatalogGroup

| Field | Type |
|---|---|
| `category` | `String!` |
| `services` | `[PortalService!]!` |

#### PortalDraftReview

| Field | Type |
|---|---|
| `requestId` | `ID!` |
| `status` | `String!` |
| `service` | `PortalService!` |
| `travelers` | `[PortalReviewTraveler!]!` |
| `quote` | `PortalReviewQuote!` |
| `errors` | `[String!]!` |
| `violations` | `JSON!` |
| `canSubmit` | `Boolean!` |

#### PortalHome

| Field | Type |
|---|---|
| `userName` | `String!` |
| `agencyName` | `String!` |
| `agencyStatus` | `String!` |
| `isMainAgent` | `Boolean!` |
| `openRequestsCount` | `Int!` |
| `actionNeededCount` | `Int!` |
| `unreadNotifications` | `Int!` |
| `wallet` | `PortalWalletSummary` |
| `quickActions` | `[PortalQuickAction!]!` |
| `services` | `[PortalService!]!` |
| `servicesTotal` | `Int!` |
| `recentRequests` | `[PortalRequestCard!]!` |

#### PortalInfoRequest

| Field | Type |
|---|---|
| `message` | `String!` |
| `requestedAt` | `DateTime` |
| `deadlineAt` | `DateTime` |
| `remainingSeconds` | `Int` |

#### PortalNotification

| Field | Type |
|---|---|
| `id` | `ID!` |
| `eventType` | `String!` |
| `kind` | `String!` |
| `tone` | `String!` |
| `iconKey` | `String!` |
| `isRead` | `Boolean!` |
| `readAt` | `DateTime` |
| `createdAt` | `DateTime!` |
| `group` | `String!` |
| `requestId` | `ID` |
| `referenceCode` | `String` |
| `serviceNameAr` | `String` |
| `serviceNameEn` | `String` |
| `travelerLabel` | `String` |
| `travelerLabelMasked` | `Boolean!` |
| `amount` | `Decimal` |
| `currency` | `String` |
| `ticketId` | `ID` |
| `ticketSubject` | `String` |

#### PortalNotificationList

| Field | Type |
|---|---|
| `items` | `[PortalNotification!]!` |
| `unreadCount` | `Int!` |
| `total` | `Int!` |
| `hasMore` | `Boolean!` |

#### PortalPendingTopUp

| Field | Type |
|---|---|
| `id` | `ID!` |
| `number` | `String` |
| `status` | `String!` |
| `amount` | `Decimal!` |
| `currency` | `String!` |
| `method` | `String!` |
| `referenceNumber` | `String!` |
| `paymentAccountTitle` | `String` |
| `hasReceipt` | `Boolean!` |
| `createdAt` | `DateTime!` |

#### PortalQuickAction

| Field | Type |
|---|---|
| `key` | `String!` |
| `enabled` | `Boolean!` |
| `badge` | `Int` |

#### PortalReceiptUpload

| Field | Type |
|---|---|
| `endpoint` | `String!` |
| `kind` | `String!` |
| `maxBytes` | `Int!` |
| `contentTypes` | `[String!]!` |

#### PortalRequestActions

| Field | Type |
|---|---|
| `canCancel` | `Boolean!` |
| `cancelReleasesFunds` | `Boolean!` |
| `canAddDocuments` | `Boolean!` |
| `canViewDocuments` | `Boolean!` |
| `canDownloadResult` | `Boolean!` |
| `canDecideApproval` | `Boolean!` |
| `canContactSupport` | `Boolean!` |

#### PortalRequestCard

| Field | Type |
|---|---|
| `id` | `ID!` |
| `referenceCode` | `String!` |
| `status` | `String!` |
| `statusGroup` | `String!` |
| `serviceId` | `ID!` |
| `serviceCode` | `String!` |
| `serviceNameAr` | `String!` |
| `serviceNameEn` | `String!` |
| `iconKey` | `String!` |
| `travelerCount` | `Int!` |
| `travelerNames` | `[String!]!` |
| `travelerNamesMasked` | `Boolean!` |
| `stage` | `Int!` |
| `stageCount` | `Int!` |
| `stageKey` | `String` |
| `remainingKind` | `String` |
| `remainingSeconds` | `Int` |
| `deadlineAt` | `DateTime` |
| `slaState` | `String!` |
| `amount` | `Decimal` |
| `currency` | `String` |
| `agentId` | `ID!` |
| `agentName` | `String!` |
| `createdAt` | `DateTime!` |
| `updatedAt` | `DateTime!` |

#### PortalRequestFilter

| Field | Type |
|---|---|
| `key` | `String!` |
| `count` | `Int!` |

#### PortalRequestList

| Field | Type |
|---|---|
| `items` | `[PortalRequestCard!]!` |
| `total` | `Int!` |
| `hasMore` | `Boolean!` |
| `filters` | `[PortalRequestFilter!]!` |
| `attention` | `PortalAttention!` |
| `hasAnyRequests` | `Boolean!` |
| `canCreate` | `Boolean!` |

#### PortalRequestTracking

| Field | Type |
|---|---|
| `request` | `PortalRequestCard!` |
| `filedAt` | `DateTime!` |
| `feeTotal` | `Decimal` |
| `feeCurrency` | `String` |
| `travelerCount` | `Int!` |
| `timeline` | `[PortalTimelineStep!]!` |
| `infoRequest` | `PortalInfoRequest` |
| `terminal` | `PortalTerminal` |
| `travelers` | `[PortalTrackedTraveler!]!` |
| `outputs` | `[PortalTrackedOutput!]!` |
| `actions` | `PortalRequestActions!` |
| `submittedByName` | `String!` |
| `onBehalf` | `Boolean!` |

#### PortalReviewQuote

| Field | Type |
|---|---|
| `currency` | `String` |
| `unitPrice` | `Decimal` |
| `travelerCount` | `Int!` |
| `total` | `Decimal` |
| `balance` | `Decimal` |
| `availableAfter` | `Decimal` |
| `creditLimit` | `Decimal` |
| `fundsSufficient` | `Boolean` |
| `holdDeferred` | `Boolean!` |
| `slaHours` | `Int!` |

#### PortalReviewTraveler

| Field | Type |
|---|---|
| `id` | `ID!` |
| `index` | `Int!` |
| `name` | `String` |
| `nameMasked` | `Boolean!` |
| `passportNumber` | `String` |
| `documentsCount` | `Int!` |

#### PortalService

| Field | Type |
|---|---|
| `id` | `ID!` |
| `code` | `String!` |
| `nameAr` | `String!` |
| `nameEn` | `String!` |
| `category` | `String!` |
| `subtype` | `String!` |
| `iconKey` | `String!` |
| `price` | `Decimal` |
| `currency` | `String` |
| `slaHours` | `Int!` |
| `requiresApproval` | `Boolean!` |

#### PortalStatementRow

| Field | Type |
|---|---|
| `id` | `ID!` |
| `type` | `String!` |
| `direction` | `String!` |
| `titleKind` | `String!` |
| `amount` | `Decimal!` |
| `signedAmount` | `Decimal!` |
| `currency` | `String!` |
| `balanceAfter` | `Decimal!` |
| `createdAt` | `DateTime!` |
| `day` | `String!` |
| `requestId` | `ID` |
| `referenceCode` | `String` |
| `serviceNameAr` | `String` |
| `serviceNameEn` | `String` |
| `method` | `String` |

#### PortalSubAgent

| Field | Type |
|---|---|
| `id` | `ID!` |
| `name` | `String!` |
| `initial` | `String!` |
| `status` | `String!` |
| `city` | `String!` |
| `ownerName` | `String` |
| `requestCount` | `Int!` |
| `monthRequestCount` | `Int!` |
| `balance` | `Decimal` |
| `currency` | `String` |
| `monthMargin` | `Decimal` |
| `createdAt` | `DateTime!` |
| `canFund` | `Boolean!` |
| `canSuspend` | `Boolean!` |
| `canActivate` | `Boolean!` |

#### PortalTerminal

| Field | Type |
|---|---|
| `kind` | `String!` |
| `at` | `DateTime` |
| `reason` | `String` |

#### PortalTimelineStep

| Field | Type |
|---|---|
| `key` | `String!` |
| `state` | `String!` |
| `at` | `DateTime` |
| `blocked` | `Boolean!` |
| `expectedWithinHours` | `Int` |

#### PortalTopUpMethod

| Field | Type |
|---|---|
| `method` | `String!` |
| `accountKinds` | `[String!]!` |

#### PortalTopUpOptions

| Field | Type |
|---|---|
| `currency` | `String!` |
| `minimumAmount` | `Decimal` |
| `methods` | `[PortalTopUpMethod!]!` |
| `accounts` | `[PaymentAccount!]!` |
| `receiptUpload` | `PortalReceiptUpload!` |
| `pendingCount` | `Int!` |
| `canRequest` | `Boolean!` |

#### PortalTrackedOutput

| Field | Type |
|---|---|
| `id` | `ID!` |
| `outputType` | `String!` |
| `uploadedAt` | `DateTime!` |
| `fileId` | `ID!` |
| `fileName` | `String!` |
| `contentType` | `String!` |
| `sizeBytes` | `Int!` |

#### PortalTrackedTraveler

| Field | Type |
|---|---|
| `id` | `ID!` |
| `index` | `Int!` |
| `name` | `String` |
| `nameMasked` | `Boolean!` |
| `status` | `String!` |
| `documentsCount` | `Int!` |

#### PortalWallet

| Field | Type |
|---|---|
| `agentId` | `ID!` |
| `agentName` | `String!` |
| `summary` | `PortalWalletSummary!` |
| `pendingTopUps` | `[PortalPendingTopUp!]!` |
| `statement` | `[PortalStatementRow!]!` |
| `statementTotal` | `Int!` |
| `hasMore` | `Boolean!` |
| `canTopUp` | `Boolean!` |
| `canExportStatement` | `Boolean!` |

#### PortalWalletSummary

| Field | Type |
|---|---|
| `currency` | `String!` |
| `balance` | `Decimal!` |
| `held` | `Decimal!` |
| `total` | `Decimal!` |
| `creditLimit` | `Decimal!` |
| `spendable` | `Decimal!` |
| `creditUsed` | `Decimal!` |

#### PrefillCandidate

| Field | Type |
|---|---|
| `requestId` | `ID!` |
| `referenceCode` | `String!` |
| `serviceNameEn` | `String!` |
| `serviceNameAr` | `String!` |
| `createdAt` | `String!` |
| `travelerCount` | `Int!` |

#### PrefillResult

| Field | Type |
|---|---|
| `travelers` | `[JSON!]!` |

#### RecoveryCodesResult

| Field | Type |
|---|---|
| `codes` | `[String!]!` |

#### ReportColumn

| Field | Type |
|---|---|
| `key` | `String!` |
| `labelEn` | `String!` |
| `labelAr` | `String!` |
| `kind` | `String!` |

#### ReportExport

| Field | Type |
|---|---|
| `filename` | `String!` |
| `contentType` | `String!` |
| `contentBase64` | `String!` |
| `rowCount` | `Int!` |

#### ReportResult

| Field | Type |
|---|---|
| `columns` | `[ReportColumn!]!` |
| `rows` | `JSON!` |
| `totals` | `JSON` |
| `totalRows` | `Int!` |
| `truncated` | `Boolean!` |

#### Request

| Field | Type |
|---|---|
| `id` | `ID!` |
| `referenceCode` | `String!` |
| `serviceType` | `ServiceType!` |
| `status` | `String!` |
| `slaDeadline` | `DateTime` |
| `infoRequiredAt` | `DateTime` |
| `createdAt` | `DateTime!` |
| `updatedAt` | `DateTime!` |
| `slaState` | `String!` |
| `slaRemainingSeconds` | `Int` |
| `outputs` | `[RequestOutput!]!` |
| `notes` | `[RequestNote!]!` |
| `refundable` | `Boolean!` |
| `money` | `RequestMoney` |
| `agent` | `Agent!` |
| `submittedBy` | `User!` |
| `travelers` | `[RequestTraveler!]!` |
| `sellingPrice` | `Decimal` |

#### RequestDocument

| Field | Type |
|---|---|
| `id` | `ID!` |
| `documentRequirement` | `ServiceDocumentRequirement!` |
| `uploadedAt` | `DateTime!` |
| `file` | `StoredFile` |

#### RequestMoney

| Field | Type |
|---|---|
| `currency` | `String!` |
| `travelerCount` | `Int!` |
| `holdStatus` | `String!` |
| `sellingPrice` | `Decimal` |
| `margin` | `Decimal` |

#### RequestNote

| Field | Type |
|---|---|
| `id` | `ID!` |
| `body` | `String!` |
| `createdAt` | `DateTime!` |
| `author` | `User` |

#### RequestOutput

| Field | Type |
|---|---|
| `id` | `ID!` |
| `outputType` | `String!` |
| `uploadedAt` | `DateTime!` |
| `file` | `StoredFile` |

#### RequestTraveler

| Field | Type |
|---|---|
| `id` | `ID!` |
| `status` | `String!` |
| `fieldValues` | `[FieldValue!]!` |
| `documents` | `[RequestDocument!]!` |

#### ServiceCompanion

| Field | Type |
|---|---|
| `companionId` | `ID!` |
| `nameEn` | `String!` |
| `nameAr` | `String!` |
| `dueHours` | `Int!` |
| `enabled` | `Boolean!` |

#### ServiceDocumentRequirement

| Field | Type |
|---|---|
| `id` | `ID!` |
| `documentKey` | `String!` |
| `labelAr` | `String!` |
| `labelEn` | `String!` |
| `required` | `Boolean!` |

#### ServiceFieldDefinition

| Field | Type |
|---|---|
| `id` | `ID!` |
| `stepNumber` | `Int!` |
| `fieldKey` | `String!` |
| `labelAr` | `String!` |
| `labelEn` | `String!` |
| `fieldType` | `String!` |
| `required` | `Boolean!` |
| `displayOrder` | `Int!` |
| `isSensitive` | `Boolean!` |
| `validationRules` | `String!` |
| `effectiveRules` | `String!` |

#### ServiceType

| Field | Type |
|---|---|
| `id` | `ID!` |
| `code` | `String!` |
| `nameAr` | `String!` |
| `nameEn` | `String!` |
| `category` | `String!` |
| `isActive` | `Boolean!` |
| `subtype` | `String!` |
| `slaHours` | `Int!` |
| `requiresManagementApproval` | `Boolean!` |
| `imageUrl` | `String` |
| `hasImage` | `Boolean!` |
| `companions` | `[ServiceCompanion!]!` |
| `fields` | `[ServiceFieldDefinition!]!` |
| `documents` | `[ServiceDocumentRequirement!]!` |
| `myPrice` | `Decimal` |
| `priceForAgent(agentId: ID!)` | `Decimal` |

#### StatementPdf

| Field | Type |
|---|---|
| `filename` | `String!` |
| `contentBase64` | `String!` |
| `rowCount` | `Int!` |
| `openingBalance` | `Decimal!` |
| `closingBalance` | `Decimal!` |
| `currency` | `String!` |

#### StoredFile

| Field | Type |
|---|---|
| `id` | `ID!` |
| `originalName` | `String!` |
| `contentType` | `String!` |
| `sizeBytes` | `Int!` |

#### SubmittedTopUp

| Field | Type |
|---|---|
| `id` | `ID!` |
| `number` | `String!` |
| `status` | `String!` |
| `amount` | `Decimal!` |
| `currency` | `String!` |
| `method` | `String!` |
| `referenceNumber` | `String!` |
| `paymentAccount` | `TopUpAccountRef` |
| `hasReceipt` | `Boolean!` |
| `createdAt` | `DateTime!` |

#### Ticket

| Field | Type |
|---|---|
| `id` | `ID!` |
| `type` | `String!` |
| `category` | `String!` |
| `priority` | `String!` |
| `assignedTo` | `User` |
| `subjectAgent` | `Agent` |
| `openedBy` | `User!` |
| `requester` | `User` |
| `payload` | `JSON!` |
| `status` | `String!` |
| `audience` | `String!` |
| `resolvedBy` | `User` |
| `resolutionNote` | `String!` |
| `createdAt` | `DateTime!` |
| `resolvedAt` | `DateTime` |
| `isEscalated` | `Boolean!` |
| `escalatedAt` | `DateTime` |
| `escalatedBy` | `User` |
| `escalationReason` | `String!` |
| `attachmentFileId` | `ID` |
| `team` | `String!` |
| `dueAt` | `DateTime` |
| `firstResponseAt` | `DateTime` |
| `isOverdue` | `Boolean!` |
| `slaState` | `String!` |
| `categoryInfo` | `TicketCategory` |
| `currency` | `String` |
| `assignedEmployees` | `[User!]!` |
| `relatedRequest` | `Request` |
| `relatedRequests` | `[Request!]!` |
| `unreadCount` | `Int!` |
| `isUnread` | `Boolean!` |
| `messages` | `[TicketMessage!]!` |

#### TicketCategory

| Field | Type |
|---|---|
| `id` | `ID!` |
| `code` | `String!` |
| `nameAr` | `String!` |
| `nameEn` | `String!` |
| `ticketType` | `String!` |
| `defaultPriority` | `String!` |
| `slaHours` | `Int` |
| `defaultTeam` | `String` |
| `audience` | `String!` |
| `isActive` | `Boolean!` |
| `sortOrder` | `Int!` |

#### TicketMessage

| Field | Type |
|---|---|
| `id` | `ID!` |
| `sender` | `User!` |
| `message` | `String!` |
| `createdAt` | `DateTime!` |
| `attachmentFileId` | `ID` |
| `attachmentName` | `String!` |

#### TicketRatingResult

| Field | Type |
|---|---|
| `ticketId` | `ID!` |
| `rating` | `Int!` |
| `ratedAt` | `DateTime!` |

#### TicketStats

| Field | Type |
|---|---|
| `mine` | `Int!` |
| `unassigned` | `Int!` |
| `team` | `Int!` |
| `escalated` | `Int!` |
| `overdue` | `Int!` |
| `active` | `Int!` |
| `total` | `Int!` |

#### TopUpAccountRef

| Field | Type |
|---|---|
| `id` | `ID!` |
| `title` | `String!` |
| `currency` | `String!` |
| `kind` | `String!` |

#### Transaction

| Field | Type |
|---|---|
| `id` | `ID!` |
| `type` | `String!` |
| `status` | `String!` |
| `amount` | `Decimal!` |
| `note` | `String!` |
| `createdAt` | `DateTime!` |
| `agent` | `Agent!` |
| `currency` | `String!` |

#### User

| Field | Type |
|---|---|
| `id` | `ID!` |
| `fullName` | `String!` |
| `agent` | `Agent` |
| `email` | `String!` |
| `otpEnabled` | `Boolean!` |
| `phone` | `String!` |
| `avatarUrl` | `String` |
| `isActive` | `Boolean!` |
| `twoFactorEnrolled` | `Boolean!` |
| `recoveryCodesRemaining` | `Int!` |
| `userType` | `String!` |
| `employeePosition` | `String` |
| `agentPosition` | `String` |
| `permissions` | `[String!]!` |
| `rolePermissionCodes` | `[String!]!` |

#### Wallet

| Field | Type |
|---|---|
| `id` | `ID!` |
| `balance` | `Decimal!` |
| `creditLimit` | `Decimal!` |
| `currency` | `String!` |
| `transactions(limit: Int!, offset: Int!, status: String, type: String)` | `[Transaction!]!` |
| `transactionsCount(status: String, type: String)` | `Int!` |

### Input types

#### BatchTravelerInput

| Field | Type |
|---|---|
| `fieldValues` | `[FieldValueInput!]!` |

#### ContactMessageInput

| Field | Type |
|---|---|
| `name` | `String!` |
| `email` | `String!` |
| `subject` | `String!` |
| `message` | `String!` |
| `phone` | `String` |
| `locale` | `String` |

#### FieldValueInput

| Field | Type |
|---|---|
| `fieldDefinitionId` | `ID!` |
| `value` | `String!` |

#### MainAgentSignupInput

| Field | Type |
|---|---|
| `name` | `String!` |
| `ownerEmail` | `String!` |
| `ownerFullName` | `String!` |
| `ownerPassword` | `String!` |
| `locale` | `String` |
| `city` | `String!` |
| `licenseNumber` | `String!` |
| `ownerPhone` | `String!` |
| `acceptedTerms` | `Boolean!` |

#### StaffUserInput

| Field | Type |
|---|---|
| `email` | `String!` |
| `fullName` | `String!` |
| `password` | `String!` |
| `position` | `String!` |
| `branchId` | `ID` |

#### SubAgentInput

| Field | Type |
|---|---|
| `name` | `String!` |
| `ownerEmail` | `String!` |
| `ownerFullName` | `String!` |
| `ownerPassword` | `String!` |

### Enumerations


## Error codes

Every failed operation carries one of these in `errors[0].extensions.code` (some also carry `extensions.params`). The text is the English message the web app shows; the Arabic text is in the web app's `ar.json`. Show your own localized text keyed by `code`, never the raw server text.

| Code | English message |
|---|---|
| `action_invalid` | The action must be credit or debit. |
| `ad_cta_incomplete` | A button needs both a label and a link. |
| `ad_dates_invalid` | The end date must be after the start date. |
| `ad_image_not_found` | That image could not be found. Upload it again. |
| `ad_image_type_invalid` | The image must be a PNG or JPEG file. |
| `ad_limit_reached` | The maximum number of ads has been reached. Archive one first. |
| `ad_link_invalid` | The link must be an https address or a page of the portal. |
| `ad_not_found` | Ad not found. |
| `ad_placement_invalid` | Choose a valid ad placement. |
| `ad_reorder_invalid` | The new order does not match the ads in this placement. |
| `ad_status_invalid` | Choose a valid ad status. |
| `ad_text_invalid` | The text contains characters that are not allowed. |
| `ad_text_too_long` | The text is too long. |
| `ad_tier_invalid` | Tiers must be A, B or C. |
| `ad_title_required` | The ad needs a title in at least one language. |
| `agency_details_invalid` | The agency details are not valid. |
| `agency_name_invalid` | The agency name is required (up to 120 characters). |
| `agency_no_wallet` | This agency has no wallet yet. Contact Seen support. |
| `agency_pending` | Your agency's registration is still pending Seen's approval. |
| `agency_suspended` | This agency's account has been suspended. |
| `agent_not_active` | Requests can only be submitted for an active agency. |
| `agent_not_found` | Agency not found. |
| `agent_pending_needs_approval` | A pending main agent must be approved by Seen first. |
| `agent_required` | Choose the agency first. |
| `agent_required_on_behalf` | Choose the agency you are submitting on behalf of. |
| `agent_side_only` | This action is available to agency users only. |
| `agent_side_role` | Use the agency-side role assignment for agency users. |
| `agent_status_invalid` | This agency cannot be approved in its current status ({{status}}). |
| `already_escalated` | This support request is already escalated. |
| `already_rated` | This support request has already been rated. |
| `amount_invalid` | Enter a valid amount (up to two decimal places). |
| `amount_positive` | The amount must be greater than zero. |
| `assignee_must_be_staff` | Only Seen staff can be assigned to a support request. |
| `attachment_invalid` | The attachment data is not valid. |
| `attachment_mismatch` | The attachment content does not match its declared type. |
| `attachment_not_found` | That attachment could not be found. Please add it again. |
| `attachment_too_large` | The attachment is too large (max 1.5 MB). |
| `attachment_type_unsupported` | Unsupported attachment type (allowed: PNG, JPEG, PDF). |
| `automation_script_invalid` | This service's automation script is not valid. A person completes its requests until it is fixed. |
| `automation_script_missing` | This service has no automation script. |
| `avatar_not_found` | That picture could not be found. Upload it again. |
| `avatar_type_invalid` | A profile picture must be a PNG or JPEG image. |
| `branch_not_found` | Branch not found. |
| `branch_required` | A Branch Manager must be assigned to a branch. |
| `bulk_action_unknown` | Unknown bulk action. |
| `bulk_none_selected` | Select at least one request. |
| `bulk_too_many` | At most 100 requests per bulk action. |
| `cancel_reason_required` | A reason is required to cancel a support request. |
| `capacity_invalid` | The support request capacity must be a positive whole number. |
| `catalog_value_invalid` | One of the values is not valid. Check the name, hours, order and field type, then try again. |
| `category_protected` | This is a system category and cannot be switched off or removed. |
| `category_type_locked` | The support request type of an existing category cannot be changed. |
| `category_unavailable` | This support request category is no longer available. |
| `category_unknown` | Unknown support request category. |
| `category_wrong_kind` | This category cannot be used for this kind of support request. |
| `city_invalid` | Enter a valid city (up to 80 characters). |
| `code_invalid` | The code may only contain letters, digits, dashes and underscores (max 50). |
| `companion_already_linked` | That request already serves another follow-up. |
| `companion_is_itself` | A service cannot be its own follow-up. |
| `companion_not_submitted` | That request has not been submitted, or was rejected or cancelled. |
| `companion_request_not_found` | No request has that reference. |
| `companion_task_closed` | That follow-up is already closed. |
| `companion_task_not_found` | That follow-up was not found. |
| `companion_wrong_agency` | That request belongs to a different agency. |
| `companion_wrong_service` | That request is for a different service. |
| `contact_email_invalid` | Enter a valid e-mail address. |
| `contact_message_invalid` | Write a message of at least 10 characters. |
| `contact_message_not_found` | That message was not found. |
| `contact_name_invalid` | Enter your name. |
| `contact_phone_invalid` | Enter a valid phone number or leave it empty. |
| `contact_subject_invalid` | Write a short subject. |
| `copy_same_service` | Choose a different service to copy from. |
| `credit_limit_negative` | The credit limit cannot be negative. |
| `current_password_invalid` | The current password is not correct. |
| `date_invalid` | Invalid date. Use YYYY-MM-DD. |
| `description_too_long` | The description is too long. Keep it within {{max}} characters. |
| `document_key_exists` | This document key already exists for this service. |
| `document_not_found` | Document requirement not found. |
| `document_requirement_invalid` | This document is not one the service asks for. |
| `document_upload_not_allowed` | Documents can only be added while the request is a draft or waiting for information. |
| `due_hours_invalid` | The time must be between 1 hour and 30 days. |
| `email_change_link_invalid` | This confirmation link is invalid or has expired. |
| `email_invalid` | Enter a valid e-mail address. |
| `email_not_verified` | The owner has not confirmed their email yet. |
| `email_send_failed` | The e-mail could not be sent. Try again in a moment. |
| `employee_not_found` | Employee not found. |
| `enrollment_challenge_invalid` | This sign-in step expired. Please sign in again. |
| `enrollment_code_invalid` | That code is wrong or has expired. |
| `enrollment_code_not_sent` | We could not e-mail you the code. Ask your administrator to send you a setup link. |
| `enrollment_invalid` | This setup session has expired. Please sign in again. |
| `enrollment_link_required` | Two-factor setup needs the link that was e-mailed to you. Ask your administrator to send you a new one. |
| `escalate_resolved` | A resolved support request cannot be escalated. |
| `escalation_reason_required` | An escalation reason is required. |
| `escalation_reason_too_long` | The escalation reason is too long. Keep it within {{max}} characters. |
| `field_duplicated` | The same field was entered twice for one traveler. Please remove the duplicate. |
| `field_key_exists` | This field key already exists for this service. |
| `field_not_found` | Field not found. |
| `field_not_in_service` | That field does not belong to this request's service. |
| `field_value_not_found` | That value was not found. |
| `field_value_too_long` | One of the values is too long. Please shorten it (up to 2,000 characters). |
| `fields_mismatch` | The list of fields changed in the meantime. Reload and try again. |
| `file_content_mismatch` | The file content does not match its type. Choose the original file. |
| `file_empty` | The file is empty. |
| `file_not_found` | The file was not found or is no longer available. |
| `file_too_large` | The file is too large. The limit is 8 MB. |
| `file_type_not_allowed` | Only PDF, JPEG and PNG files are accepted. |
| `filter_invalid` | Invalid filter or sort option. |
| `four_eyes` | Four-eyes rule: the person who opened an adjustment cannot resolve it. |
| `funds_exceed_balance` | The amount exceeds your wallet's current balance. |
| `generic` | Something went wrong. Please try again. |
| `handler_not_eligible` | Only active Seen staff who may process requests can be responsible for a service. |
| `hierarchy_invalid` | Choose all, main or sub agencies. |
| `idempotency_key_invalid` | The request could not be processed. Please reload the page and try again. |
| `idempotency_key_required` | The request could not be processed. Please reload the page and try again. |
| `idempotency_key_reused` | This action was already submitted with different details. Please review the form and try again. |
| `insufficient_funds` | Insufficient funds: this would exceed the wallet's credit limit. |
| `internal_error` | Something went wrong on our side. Please try again, and contact support if it continues. |
| `invalid_automation_level` | Choose Off, Shadow or Live. |
| `invalid_credentials` | Invalid email or password. |
| `invalid_destination` | That doesn't look like a WhatsApp group ID. It should look like 1203630000000000@g.us. |
| `invalid_identifier` | Invalid identifier. |
| `invalid_payment_kind` | Choose a valid kind of payment account. |
| `invalid_purpose` | Choose a valid purpose. |
| `invalid_request` | The upload could not be processed. |
| `invalid_status` | Choose a valid status. |
| `invalid_topup_method` | Choose a valid top-up method. |
| `last_superadmin` | This is the last active Superadmin; it cannot be deactivated. |
| `legal_kind_invalid` | That page does not exist. |
| `legal_text_invalid` | That text contains characters that are not allowed. |
| `legal_text_required` | Write the title and the text in both Arabic and English. |
| `legal_text_too_long` | That text is too long. |
| `license_number_invalid` | Enter a valid licence number (up to 40 characters). |
| `margin_conflict` | Set a fixed price or a percentage, not both. |
| `margin_invalid` | The margin is not a valid number. |
| `margin_out_of_range` | The margin is outside the allowed range. |
| `message_required` | Write a message or attach a file. |
| `message_too_long` | The message is too long. Keep it within {{max}} characters. |
| `mixed_currency` | Mixed-currency wallets are not supported in finance totals yet. |
| `mrz_not_found` | The two printed lines at the bottom of the passport could not be read. Use a sharp, flat, well-lit photo of the whole page. |
| `name_too_long` | The name is too long. |
| `names_required` | Both the Arabic and English names are required. |
| `network` | Could not reach the server. Check your connection and try again. |
| `no_refresh_session` | Please sign in to continue. |
| `not_a_sub_agent` | This agency is already a Main Agent. |
| `not_authenticated` | Please sign in to continue. |
| `not_escalated` | This support request is not escalated. |
| `not_topup` | This is not a top-up transaction. |
| `note_length` | The note must be between 1 and 2000 characters. |
| `note_required` | A note is required for this action. |
| `note_too_long` | The note is too long. Please shorten it and try again. |
| `notification_not_found` | Notification not found. |
| `ocr_unavailable` | Passport reading is not available right now. Please type the details. |
| `office_exists` | An office with this name already exists. |
| `office_main_agent_only` | A Sub-Agent is served by its Main Agent's office. Assign the Main Agent instead. |
| `office_not_found` | That office no longer exists. |
| `office_required` | A Seen Branch Manager must be assigned to an office. |
| `option_invalid` | Invalid option. |
| `otp_already_enrolled` | Two-step verification is already set up on this account. To change the device, ask an administrator to reset it. |
| `otp_challenge_invalid` | The verification step expired. Please sign in again. |
| `otp_code_invalid` | The verification code is invalid. Please try again. |
| `otp_not_enrolled` | Set up two-factor authentication first. |
| `otp_not_enrolling` | Start the authenticator setup first. |
| `override_price_below_cost` | The price cannot be lower than your own price for this service. |
| `own_agency_only` | You can only do this within your own agency. |
| `own_request_forbidden` | You cannot decide a request you made yourself. |
| `owner_email_invalid` | Enter a valid email address. |
| `owner_email_taken` | This email address is already used by another account. |
| `owner_name_invalid` | The name is required (up to 120 characters). |
| `passport_not_image` | Upload a clear photo (JPEG or PNG) of the passport page that has the two printed lines at the bottom. |
| `password_unchanged` | Choose a password different from the current one. |
| `password_weak` | Choose a stronger password: at least 12 characters, not a common password, not only digits and not similar to your name or email. |
| `payment_account_currency_mismatch` | That account receives a different currency than your wallet. |
| `payment_account_not_found` | Payment account not found. |
| `payment_accounts_limit` | You have reached the maximum number of payment accounts. |
| `payment_details_required` | Give an account number or instructions the agent can follow. |
| `payment_field_too_long` | One of the payment fields is too long. |
| `payment_order_invalid` | The order must be a number between 0 and 10000. |
| `payment_title_required` | A title is required. |
| `percent_invalid` | Use a whole number from 0 to 100. |
| `period_invalid` | The start date must not be after the end date. |
| `period_too_long` | That period is too long. Choose a shorter one. |
| `permission_denied` | You do not have permission to do this. |
| `permission_not_held` | You cannot grant or clear a permission you do not hold yourself. |
| `permission_unknown` | Unknown permission. |
| `position_invalid` | Invalid staff position. |
| `prefill_from_itself` | A service cannot copy from itself. |
| `prefill_invalid` | The field mapping or the statuses are not valid for these services. |
| `prefill_source_not_found` | That request cannot be copied from. |
| `pricing_missing` | Seen has not priced this service for that agency yet. |
| `priority_invalid` | Invalid priority. |
| `processor_must_be_staff` | The processor must be a Seen staff member. |
| `processor_not_eligible` | This person can't process requests. Choose an active Seen employee who is allowed to process requests. |
| `processor_not_found` | Processor not found. |
| `profile_name_invalid` | The name must be 2 to 120 characters. |
| `profile_phone_invalid` | Enter a valid phone number, for example +967 7XX XXX XXX. |
| `profile_text_invalid` | That text contains characters that are not allowed. |
| `promotion_reason_required` | Give a reason for the promotion. |
| `provider_not_found` | Provider not found. |
| `rating_invalid` | The rating must be from 1 to 5. |
| `reason_length` | Give a reason between 3 and 500 characters. |
| `reason_too_long` | The reason is too long. Keep it within {{max}} characters. |
| `receipt_not_found` | That receipt could not be found. Upload it again. |
| `reclaim_exceeds_balance` | The amount exceeds the sub-agent's current balance. |
| `reference_too_long` | The reference number is too long. |
| `refund_already_done` | The money for this request was already returned. |
| `refund_not_applicable` | Money is returned automatically before processing starts; an admin refund applies only after that. |
| `refund_nothing_held` | No money is held for this request. |
| `refund_reason_required` | Give a reason for the refund (at least 3 characters). |
| `related_request_not_found` | The related request was not found. |
| `report_not_found` | Report not found. |
| `report_spec_invalid` | This report definition is not valid. Check the fields, filters and totals you chose. |
| `report_too_large` | This report has more than 5,000 rows. Add a filter or a grouping to make it smaller. |
| `request_not_found` | Request not found. |
| `request_not_funded` | No money is set aside for this request yet, so its review can't start. Please contact Seen support. |
| `request_not_pending_agent` | This request is not awaiting main agent approval (status: {{status}}). |
| `request_not_pending_management` | This request is not awaiting management approval (status: {{status}}). |
| `request_other_agent` | This request belongs to a different agency. |
| `request_transition_invalid` | A request cannot move from {{old}} to {{new}}. |
| `reset_email_failed` | The reset email could not be sent. |
| `reset_link_invalid` | This password reset link is invalid or has expired. |
| `resolution_note_required` | A resolution note is required to resolve this support request. |
| `resolution_note_too_long` | The resolution note is limited to {{max}} characters. |
| `response_minutes_invalid` | The response time must be a positive number of minutes. |
| `role_restricted` | Your role is not allowed to perform this action. |
| `rules_invalid` | Those checks are not allowed. |
| `scope_agents_required` | Select the agencies to apply this to. |
| `scope_invalid` | Invalid scope. |
| `search_too_long` | The search text is too long. |
| `seen_no_wallet` | Seen staff have no wallet of their own. |
| `seen_only` | This action is available to Seen staff only. |
| `seen_use_internal_ticket` | Seen staff open support requests from the internal or on-behalf support request forms. |
| `self_deactivate_forbidden` | You cannot deactivate or reactivate your own account. |
| `self_permission_forbidden` | You cannot change your own permissions. |
| `self_reset_forbidden` | You cannot reset your own two-factor authentication. Ask a Superadmin. |
| `self_role_forbidden` | You cannot change your own role. |
| `service_code_exists` | A service with the code {{code}} already exists. |
| `service_image_not_found` | That picture could not be found. Upload it again. |
| `service_image_type_invalid` | A service picture must be a PNG or JPEG image. |
| `service_not_enabled` | This service is not enabled for the agency. |
| `service_not_found` | Service not found. |
| `service_not_priced` | This service has no price for your agency yet, so the request can't continue. Please contact Seen support to set one. |
| `session_expired` | Your session expired. Please sign in again. |
| `setup_link_invalid` | This link is invalid or has expired. Ask your Seen contact for a new one. |
| `sla_hours_invalid` | SLA hours must be between 1 and 8760. |
| `statement_too_large` | There are too many movements in that period. Choose a shorter period. |
| `status_invalid` | The status must be active or suspended. |
| `status_unsupported` | That status is not supported for this action. |
| `storage_unavailable` | The file service is temporarily unavailable. Please try again shortly. |
| `sub_agent_depth` | A sub-agent cannot create its own sub-agent. |
| `subject_agent_required` | A support request visible to an agency needs a subject agency. |
| `subject_required` | A subject is required. |
| `subject_too_long` | The subject is too long. Keep it within {{max}} characters. |
| `submission_invalid` | This request cannot be submitted yet. Please review its details. |
| `superadmin_only` | This action is available to the Superadmin only. |
| `suspended_by_seen` | This agency was suspended by Seen. Only Seen can reactivate it. |
| `task_assignee_invalid` | Choose an active team member who can use the task board. |
| `task_categories_limit` | The maximum number of task categories has been reached. |
| `task_category_in_use` | This category is used by tasks and cannot be deleted. |
| `task_category_not_found` | Task category not found. |
| `task_category_order_invalid` | The category order is not valid. |
| `task_column_full` | This column is full. Finish or delete some tasks first. |
| `task_due_date_invalid` | The due date is not valid. |
| `task_field_too_long` | One of the task fields is too long. |
| `task_not_found` | Task not found. |
| `task_position_invalid` | The position cannot be negative. |
| `task_sort_invalid` | Choose a valid sort order. |
| `task_status_invalid` | Choose a valid task status. |
| `task_title_required` | The task needs a title. |
| `team_invalid` | Choose a valid team. |
| `template_not_found` | Template not found. |
| `terms_not_accepted` | You must accept the Terms and the Privacy policy to sign up. |
| `ticket_locked` | This support request is {{status}} and can no longer be changed. |
| `ticket_not_found` | Support request not found. |
| `ticket_not_resolved` | Only a resolved or closed support request can be rated. |
| `ticket_resolve_status` | A support request in status {{status}} cannot be resolved. |
| `ticket_take_first` | Take this support request (become its assignee) before resolving it. |
| `ticket_team_or_assignee` | Choose a team or an assignee for an internal support request. |
| `ticket_transition_invalid` | A support request cannot move from {{old}} to {{new}}. |
| `ticket_wrong_kind` | This action does not apply to this kind of support request. |
| `tier_invalid` | The tier must be A, B or C. |
| `too_many_attempts` | Too many attempts. Please wait about {{minutes}} minute(s) before trying again. |
| `too_many_field_values` | This traveler has too many values entered. Please check the form and try again. |
| `too_many_files` | This traveler already has the maximum number of files. |
| `too_many_handlers` | A service can list at most 50 people. |
| `too_many_ids` | You selected too many agencies at once. Choose up to 100 and try again. |
| `too_many_related_requests` | A support request can be linked to at most 10 requests. |
| `too_many_saved_reports` | You have the maximum number of saved reports. Delete one first. |
| `too_many_travelers` | A request can hold at most 50 travelers. Split the list into more than one request. |
| `topup_below_minimum` | The amount is below the minimum top-up. |
| `topup_status_invalid` | This top-up can no longer be processed (status: {{status}}). |
| `transaction_not_found` | Transaction not found. |
| `transfer_self` | A wallet cannot be transferred to itself. |
| `traveler_add_not_draft` | Travelers can only be added while the request is still a draft. |
| `traveler_transition_invalid` | A traveler cannot move from {{old}} to {{new}}. |
| `two_factor_already_enrolled` | This person already has two-factor authentication. Reset it first to enrol again. |
| `use_resolve` | Use Resolve to resolve a support request (a resolution note is required). |
| `user_not_found` | User not found. |
| `validation_failed` | Some values need correcting. |
| `verification_link_invalid` | This confirmation link is invalid or has expired. Ask for a new one from the sign-up page. |
| `visibility_invalid` | Invalid default visibility. |
| `wallet_not_found` | This agency has no wallet yet. Please contact Seen support. |
