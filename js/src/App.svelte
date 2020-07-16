
<script>
  import { onMount } from "svelte";
  import moment from "moment";
  import ifvisible from "ifvisible.js";
  export let refreshing = false;
  let updatedAt = null;
  export let updatedAtText = null;
  export let patchSets = {
    mine: [],
    others: [],
    closed: []
  }
  let lastFetch = Date.now();
  async function fetchChanges() {
    await fetch(`/changes`)
      .then(r => r.json())
      .then(data => {
        patchSets = data;
        refreshing = false;
        lastFetch = Date.now();
        updatedAt = Date.now()
        updatedAtText = moment(updatedAt).fromNow();
      });
  }
  onMount(() => {
    fetchChanges();
    const updatedAtInterval = setInterval(() => {
      updatedAtText = updatedAt && moment(updatedAt).fromNow();
    }, 5000);

    return () => {
      clearInterval(updatedAtInterval);
    };
  })
  ifvisible.on("focus", function(){
    if (Date.now() - lastFetch > 120000) {
      refreshing = true;
      fetchChanges();
    }
  });
  function sizeBarColor(percent) {
    if (percent <= 20) {
      return "#74D900";
    } else if (percent <= 40) {
      return "#B2D500";
    } else if (percent <= 60) {
      return "#D2B500";
    } else if (percent <= 80) {
      return "#CE7400";
    } else if (percent <= 99) {
      return "#CA3500";
    } else {
      return "#C60006";
    }
  }
  function statusColor(status) {
    if (status === "Merge Conflict") {
      return "#dc5c60";
    } else if (status === "Merged") {
      return "#5b9d52";
    } else {
      return "#9e9e9e";
    }
  }
  function reviewText(review, isVerified = false) {
    if (isVerified) {
      if (review.status === "-2") {
        return "✕";
      } else if (review.status === "+2") {
        return "✓";
      }
    } else if (review.status !== null) {
      return review.status
    }
    return ""
  }
  function reviewColor(review) {
    if (review.status && review.status.startsWith("-")) {
      if (review.is_self) {
        return "#ff3e3e";
      } else if (review.is_bot) {
        return "#c67676";
      } else {
        return "#be2828";
      }
    } else if (review.status && review.status.startsWith("+")) {
      if (review.is_self) {
        return "#56eb5c";
      } else {
        return "#328036";
      }
    }
  }
</script>

<main>
  <header>BetterGerrit</header>
  {#if refreshing}
    <div class="refreshing">Refreshing <div class="loader" /></div>
  {/if}
  <table>
    <tr>
      <th class="td-first">Subject</th>
      <th>Status</th>
      <th>Owner</th>
      <th>Repo</th>
      <th>Updated</th>
      <th>Size</th>
      <th class="border-left">CR</th>
      <th class="border-left">PR</th>
      <th class="border-left">QA</th>
      <th class="border-left">V</th>
    </tr>
    {#each [["mine", "My Changes"], ["others", "Others' Changes"], ["closed", "Closed"]] as section (section[0])}
      <tr><td colspan="10" class="tr-header td-first"><b>{section[1]}</b></td></tr>
      {#each patchSets[section[0]] as p (p.id)}
        <tr>
          <td class="td-first"><a href="{window.BASE_API_URL}/c/{p.project}/+/{p.id}">
            {#if p.changed_after_self_activity && section[0] !== "closed"}
              <b style="color: rgb(232, 234, 237);">{p.subject}</b>
            {:else}
              {p.subject}
            {/if}
          </a></td>
          <td style="color: {statusColor(p.status)};">{p.status}</td>
          <td><a href="{window.BASE_API_URL}/q/owner:{p.owner_email}">{p.owner_name}</td>
          <td><a href="{window.BASE_API_URL}/q/project:{p.project}">{p.project}</td>
          <td>{moment.utc(p.updated_at).local().fromNow()}</td>
          <td class="size-bar-wrapper"><div class="size-bar-inner" style="width: {p.size}%;background-color: {sizeBarColor(p.size)};"></div></td>
          <td class="border-left" style="background-color: {reviewColor(p.reviews.cr)};" title="{p.reviews.cr.person}">
            <div role="img" title="{p.reviews.cr.person}">{reviewText(p.reviews.cr)}</div>
          </td>
          <td class="border-left" style="background-color: {reviewColor(p.reviews.pr)};" title="{p.reviews.pr.person}">
            <div role="img" title="{p.reviews.pr.person}">{reviewText(p.reviews.pr)}</div>
          </td>
          <td class="border-left" style="background-color: {reviewColor(p.reviews.qa)};" title="{p.reviews.qa.person}">
            <div role="img" title="{p.reviews.qa.person}">{reviewText(p.reviews.qa)}</div>
          </td>
          <td class="border-left" style="background-color: {reviewColor(p.reviews.v)};" title="{p.reviews.v.person}">
            <div role="img">{reviewText(p.reviews.v, true)}</div>
          </td>
        </tr>
      {/each}
    {/each}
  </table>
  {#if updatedAtText}
    <div class="updated">Updated {updatedAtText}</div>
  {/if}
</main>

<style>
  .size-bar-wrapper {
    width: 100px;
  }
  .size-bar-inner {
    background-color: red;
    height: 20px;
  }
  header {
    background-color: rgb(60, 64, 67);
    color: rgb(232, 234, 237);
    padding: 12px;
    font-size: 24.5px;
  }
  table {
    padding: 8px;
    width: 100%;
    border-collapse: collapse;
  }
  th {
    background-color: #131416;
    color: #e8eaed;
    text-align: left;
    padding: 12px 4px;
    border-top: 1px solid #5f6368;
    border-bottom: 1px solid #5f6368;
  }
  .border-left {
    border-left: 1px solid #5f6368;
    text-align: center;
  }
  tr {
    padding: 4px;
    background-color: #131416;
  }
  .updated {
    text-align: center;
    margin-top: 16px;
    color: rgb(218, 220, 224);
  }
  .tr-header {
    padding: 4px;
    color: #ced0d3;
    background-color: #343537;
  }
  td {
    padding: 4px;
    color: rgb(218, 220, 224);
    border-bottom: 1px solid #5f6368;
  }
  .td-first {
    padding-left: 16px;
  }
  td div[role="img"] {
    width: 20px;
    height: 20px;
    text-align: center;
    margin: auto;
    color: black;
  }
  a {
    color: rgb(218, 220, 224);
  }
  td a b {
    font-weight: 900;
  }
  .refreshing {
    color: white;
    position: fixed;
    top: 50px;
    left: 50%;
    background-color: #515355ed;
    padding: 20px;
    border-radius: 5px;
    height: 20px;
    -webkit-transform: translateX(-50%);
    -ms-transform: translateX(-50%);
    transform: translateX(-50%);
  }
  .loader {
    display: inline-block;
    font-size: 2px;
    width: 1em;
    height: 1em;
    border-radius: 50%;
    position: relative;
    text-indent: -9999em;
    -webkit-animation: load5 1.1s infinite ease;
    animation: load5 1.1s infinite ease;
    -webkit-transform: translateY(-5px);
    -ms-transform: translateY(-5px);
    transform: translateY(-5px);
    margin-left: 10px;
  }
  @-webkit-keyframes load5 {
    0%,
    100% {
      box-shadow: 0em -2.6em 0em 0em #ffffff, 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.5), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.7);
    }
    12.5% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.7), 1.8em -1.8em 0 0em #ffffff, 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.5);
    }
    25% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.5), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.7), 2.5em 0em 0 0em #ffffff, 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    37.5% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.5), 2.5em 0em 0 0em rgba(255, 255, 255, 0.7), 1.75em 1.75em 0 0em #ffffff, 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    50% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.5), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.7), 0em 2.5em 0 0em #ffffff, -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    62.5% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.5), 0em 2.5em 0 0em rgba(255, 255, 255, 0.7), -1.8em 1.8em 0 0em #ffffff, -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    75% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.5), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.7), -2.6em 0em 0 0em #ffffff, -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    87.5% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.5), -2.6em 0em 0 0em rgba(255, 255, 255, 0.7), -1.8em -1.8em 0 0em #ffffff;
    }
  }
  @keyframes load5 {
    0%,
    100% {
      box-shadow: 0em -2.6em 0em 0em #ffffff, 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.5), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.7);
    }
    12.5% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.7), 1.8em -1.8em 0 0em #ffffff, 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.5);
    }
    25% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.5), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.7), 2.5em 0em 0 0em #ffffff, 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    37.5% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.5), 2.5em 0em 0 0em rgba(255, 255, 255, 0.7), 1.75em 1.75em 0 0em #ffffff, 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    50% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.5), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.7), 0em 2.5em 0 0em #ffffff, -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.2), -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    62.5% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.5), 0em 2.5em 0 0em rgba(255, 255, 255, 0.7), -1.8em 1.8em 0 0em #ffffff, -2.6em 0em 0 0em rgba(255, 255, 255, 0.2), -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    75% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.5), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.7), -2.6em 0em 0 0em #ffffff, -1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2);
    }
    87.5% {
      box-shadow: 0em -2.6em 0em 0em rgba(255, 255, 255, 0.2), 1.8em -1.8em 0 0em rgba(255, 255, 255, 0.2), 2.5em 0em 0 0em rgba(255, 255, 255, 0.2), 1.75em 1.75em 0 0em rgba(255, 255, 255, 0.2), 0em 2.5em 0 0em rgba(255, 255, 255, 0.2), -1.8em 1.8em 0 0em rgba(255, 255, 255, 0.5), -2.6em 0em 0 0em rgba(255, 255, 255, 0.7), -1.8em -1.8em 0 0em #ffffff;
    }
}
</style>
